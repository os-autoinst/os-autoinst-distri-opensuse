# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1528909  - FIPS: cryptsetup

# G-Summary: Test cryptsetup in FIPS mode
#    Related test case:Case 1528909  - FIPS: cryptsetup
#    https://bugzilla.suse.com/tr_show_case.cgi?case_id=1528909
#    This case is verify the command of cryptsetup whether can be work in FIPS mode
#    Local openQA validation running: http://147.2.212.179/tests/330
# G-Maintainer: dehai <dhkong@suse.com>

use base "consoletest";
use strict;
use testapi;

sub run() {

    my $self        = @_;
    my $cryptpasswd = $testapi::password;
    select_console "root-console";

    # create a random volume.
    assert_script_run("dd if=/dev/urandom of=/test.dm bs=1k count=51200");
    wait_still_screen;

    # use cryptsetup to luksFormat and luksOpen volume
    assert_script_run("echo -e $cryptpasswd | cryptsetup -q luksFormat /test.dm");
    assert_script_run("echo -e $cryptpasswd | cryptsetup -q luksOpen /test.dm dmtest");

    # format the dmtest and mount it with /test
    assert_script_run("mkfs.ext4 /dev/mapper/dmtest");
    wait_still_screen;
    assert_script_run("mkdir /test;mount /dev/mapper/dmtest /test");

    # build some directory and files in the mount point ,try to catch file and delete directory and file
    assert_script_run("cd /test");
    assert_script_run('for x in `seq 100`; do mkdir d$x; date > d$x/f$x.log; done');
    assert_script_run("cat d39/f39.log");
    assert_script_run("rm -rf d4*");

    # release the mount point and cryptsetup luksClose dmtest
    assert_script_run("cd ~");
    assert_script_run("umount /test");
    assert_script_run("cryptsetup luksClose dmtest");

    # cleanup
    assert_script_run("rm -rf /test");
    assert_script_run("rm -rf /test.dm");
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
