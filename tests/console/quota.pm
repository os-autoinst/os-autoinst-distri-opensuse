# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: quota quota-nfs coreutils e2fsprogs
# Summary: test that uses quota command line tool to test
# This test consists on quota, configuring and use a regular user to test quota .
# If succeed, the test passes, proving that the connection is working.
#
# - Install quota and quota-nfs
# - Restart quotaon
# - Create a 100M ext3 file and mount
# - Create a test directory inside it
# - Run quotacheck
# - Run setquota
# - Run quotaon
# - As user, create a file inside test filesystem
# - Run quota
# - Create a test file and run quota again
# - Run repquota
# - Cleanup
# Maintainer: Marcelo Martins <mmartins@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $username = $testapi::username;

    select_console 'root-console';

    # install requirements
    zypper_call 'in quota quota-nfs';
    my $systemd_version = int(script_output('systemctl --version | grep systemd | awk \'{print $2}\''));
    my $use_templated_service = ($systemd_version >= 256);
    record_info('Systemd Version', "Detected systemd version: $systemd_version");

    # restart quota service
    systemctl "restart quotaon" unless $use_templated_service;

    # create filesystem image to use
    assert_script_run "dd if=/dev/zero of=/tmp/quota.img bs=10M count=10";
    assert_script_run "mkfs.ext3 -m0 /tmp/quota.img";
    assert_script_run "mkdir /tmp/quota";

    #mount disk image
    assert_script_run "mount -o loop,rw,usrquota,grpquota /tmp/quota.img /tmp/quota";
    # Escape the mount point for systemd service naming
    my $escaped_mount = "";
    if ($use_templated_service) {
        $escaped_mount = script_output("systemd-escape -p /tmp/quota");
        chomp($escaped_mount);
    }

    #creating some dir
    assert_script_run "mkdir /tmp/quota/test-directory; chmod 777 /tmp/quota/test-directory";

    #testing quota commands:
    assert_script_run "quotacheck -cug /tmp/quota";
    #setquota to user
    assert_script_run "setquota -u $username 100 200 6 10 /tmp/quota";
    #enable quota
    assert_script_run("systemctl start quotaon@" . $escaped_mount) if $use_templated_service;
    assert_script_run("quotaon /tmp/quota") unless $use_templated_service;
    # run user to use all quota
    ensure_serialdev_permissions;
    select_console 'user-console';
    assert_script_run 'cd /tmp/quota/test-directory';
    assert_script_run 'touch first_file';
    assert_script_run 'quota';
    assert_script_run 'echo {1..6} |  xargs touch';
    #quota return 1 when user exceed quota limte. Line bellow accept when return is 1.
    die 'Quota should report failure' if script_run('quota') == 0;
    assert_script_run "cd" unless $use_templated_service;

    select_console 'root-console';
    #quota report
    assert_script_run "repquota /tmp/quota";

    #Clean configurations, stop quota, dismount disc image
    assert_script_run("systemctl stop quotaon@" . $escaped_mount) if $use_templated_service;
    systemctl "stop quotaon" unless $use_templated_service;
    script_retry("umount -l /tmp/quota", timeout => 180, retry => 3) if $use_templated_service;
    assert_script_run "cd ; umount /tmp/quota" unless $use_templated_service;
    assert_script_run "rm /tmp/quota.img";
}

1;
