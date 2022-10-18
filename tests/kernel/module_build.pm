# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: kernel-default-devel kmod-compact make
# Summary: Test kernel module build
#          Example http://www.tldp.org/LDP/lkmpg/2.6/html/x121.html
# Maintainer: Petr Cervinka <pcervinka@suse.com>
# Tags: https://progress.opensuse.org/issues/49031

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;
    zypper_call "in kernel-default-devel";
    # Prepare module sources
    assert_script_run("curl -L -v " . autoinst_url . "/data/kernel/module > module.data && cpio -id < module.data && rm module.data");
    assert_script_run "cd data";
    # Build module
    assert_script_run "make";
    # Insert module
    assert_script_run "insmod hello.ko";
    # Verify that module was inserted
    assert_script_run "dmesg | grep 'Hello world'";
    # Remove module
    assert_script_run "rmmod hello";
    # Verify that module was removed
    assert_script_run "dmesg | grep 'Goodbye world'";
    # Do cleanup
    assert_script_run "make clean";
    assert_script_run "cd .. && rm -rf data";
}

1;
