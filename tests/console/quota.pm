# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test that uses quota command line tool to test
# This test consists on quota, configuring and use a regular user to test quota .
# If succeed, the test passes, proving that the connection is working.
#
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

    # restart quota service
    systemctl "restart quotaon";

    # create filesystem image to use
    assert_script_run "dd if=/dev/zero of=/tmp/quota.img bs=10M count=10";
    assert_script_run "mkfs.ext3 -m0 /tmp/quota.img";
    assert_script_run "mkdir /tmp/quota";

    #mount disk image
    assert_script_run "mount -o loop,rw,usrquota,grpquota /tmp/quota.img /tmp/quota/";

    #creating some dir
    assert_script_run "cd /tmp/quota/ ; mkdir test-directory ; chmod 77 test-directory ; ls -l";

    #testing quota commands:
    assert_script_run "quotacheck -cug /tmp/quota";
    #setquota to user
    assert_script_run "setquota -u $username 100 200 6 10 /tmp/quota";
    #enable quota
    assert_script_run "quotaon /tmp/quota";
    # run user to use all quota
    select_console 'user-console';
    assert_script_run 'cd /tmp/quota/test-directory';
    assert_script_run 'touch first_file';
    assert_script_run 'quota';
    assert_script_run 'echo {1..6} |  xargs touch';
    #quota return 1 when user exceed quota limte. Line bellow accept when return is 1.
    die 'Quota should report failure' if script_run('quota') == 0;
    assert_script_run "cd";

    select_console 'root-console';
    #quota report
    assert_script_run "repquota /tmp/quota";

    #Clean configurations, stop quota, dismount disc image
    systemctl "stop quotaon";
    assert_script_run "cd ; umount /tmp/quota";
    assert_script_run "rm /tmp/quota.img";
}

1;
