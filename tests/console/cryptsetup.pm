# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: cryptsetup
# Summary: FIPS: cryptsetup
#          Attempt to verify the command of cryptsetup whether can be worked in FIPS mode
#
# Maintainer: QE Security <none@suse.de>
# Tags: tc#1528909, poo#101575


use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_sle);

sub run {
    # Strengthen password to avoid password quality check failed on Tumbleweed
    my $cryptpasswd = $testapi::password . '123';
    select_serial_terminal;

    # Update related packages including latest systemd
    zypper_call('in cryptsetup device-mapper systemd util-linux');

    zypper_call('info cryptsetup');
    my $current_ver = script_output("rpm -q --qf '%{version}\n' cryptsetup");

    # cryptsetup attempt to update to 2.4.0+ in SLE15 SP4 base on the feature
    # SLE-20275: cryptsetup update to 2.4.0
    if (!is_sle('<15-sp4') && ($current_ver ge 2.4.0)) {
        record_info('cryptsetup version', "Version of Current cryptsetup package: $current_ver");
    }
    else {
        record_soft_failure('jsc#SLE-20275: cryptsetup version is outdate and need to be updated over 2.4.0+ for SLE15-SP4');
    }

    # Create a random volume.
    assert_script_run('dd if=/dev/urandom of=/test.dm bs=1k count=51200');
    wait_still_screen;

    # Use cryptsetup to luksFormat and luksOpen volume
    assert_script_run("echo -e $cryptpasswd | cryptsetup -q luksFormat /test.dm");
    assert_script_run("echo -e $cryptpasswd | cryptsetup -q luksOpen /test.dm dmtest");

    # Format the dmtest and mount it with /test
    assert_script_run('mkfs.ext4 /dev/mapper/dmtest');
    wait_still_screen;
    assert_script_run('mkdir /test;mount /dev/mapper/dmtest /test');

    # Build some directory and files in the mount point and try to catch file and delete directory and file
    assert_script_run('cd /test');
    assert_script_run('for x in `seq 100`; do mkdir d$x; date > d$x/f$x.log; done');
    assert_script_run('cat d39/f39.log');
    assert_script_run('rm -rf d4*');

    # Release the mount point and cryptsetup luksClose dmtest
    assert_script_run('cd ~');
    assert_script_run('umount /test');
    assert_script_run('cryptsetup luksClose dmtest');

    # Cleanup
    assert_script_run('rm -rf /test');
    assert_script_run('rm -rf /test.dm');
}

1;
