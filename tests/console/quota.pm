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
use testapi;
use utils;
use version_utils 'has_selinux';

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
    my $quota_path = "/home/$testapi::username";
    assert_script_run "dd if=/dev/zero of=$quota_path/quota.img bs=10M count=10";
    assert_script_run "mkfs.ext3 -m0 $quota_path/quota.img";
    assert_script_run "mkdir $quota_path/quota";

    #mount disk image
    my $extra_opts = has_selinux ? "usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0" : "usrquota,grpquota";
    assert_script_run "mount -o loop,rw,$extra_opts $quota_path/quota.img $quota_path/quota";
    # Escape the mount point for systemd service naming
    my $escaped_mount = "";
    if ($use_templated_service) {
        $escaped_mount = script_output("systemd-escape -p $quota_path/quota");
        chomp($escaped_mount);
    }

    #creating some dir
    assert_script_run "mkdir $quota_path/quota/test-directory; chmod 777 $quota_path/quota/test-directory";

    #testing quota commands:
    assert_script_run "quotacheck -cug $quota_path/quota";
    #setquota to user
    assert_script_run "setquota -u $username 100 200 6 10 $quota_path/quota";
    # if using SELinux, apply correct context
    if (has_selinux) {
        # https://bugzilla.suse.com/show_bug.cgi?id=1237081
        assert_script_run("semanage fcontext -a -t quota_db_t $quota_path/quota/aquota.user");
        assert_script_run("semanage fcontext -a -t quota_db_t $quota_path/quota/aquota.group");
        assert_script_run("restorecon -Rv $quota_path/quota");
    }
    #enable quota
    assert_script_run("systemctl start quotaon@" . $escaped_mount) if $use_templated_service;
    assert_script_run("quotaon $quota_path/quota") unless $use_templated_service;
    # run user to use all quota
    ensure_serialdev_permissions;
    select_console 'user-console';
    assert_script_run "cd $quota_path/quota/test-directory";
    assert_script_run 'touch first_file';
    assert_script_run 'quota';
    assert_script_run 'echo {1..6} |  xargs touch';
    #quota return 1 when user exceed quota limte. Line bellow accept when return is 1.
    die 'Quota should report failure' if script_run('quota') == 0;
    assert_script_run "cd";    # return back to ~ to be in a defined state for the next test modules

    select_console 'root-console';
    #quota report
    assert_script_run "repquota $quota_path/quota";

    #Clean configurations, stop quota, dismount disc image
    assert_script_run("systemctl stop quotaon@" . $escaped_mount) if $use_templated_service;
    systemctl "stop quotaon" unless $use_templated_service;

    script_retry("umount -l $quota_path/quota", timeout => 180, retry => 3) if $use_templated_service;
    assert_script_run "cd";    # return back to ~ to be in a defined state for the next test modules
    assert_script_run "umount $quota_path/quota" unless $use_templated_service;
    assert_script_run "rm $quota_path/quota.img";
}

1;
