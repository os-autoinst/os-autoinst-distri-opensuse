# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: FIPS: cryptsetup
#    This case is verify the command of cryptsetup whether can be work in FIPS mode
# Maintainer: dehai <dhkong@suse.com>
# Tags: tc#1528909


use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    # Strengthen password to avoid password quality check failed on Tumbleweed
    my $cryptpasswd = $testapi::password . '123';
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

1;
