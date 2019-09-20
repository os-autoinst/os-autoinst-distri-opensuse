# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test kernel module build
#          Example http://www.tldp.org/LDP/lkmpg/2.6/html/x121.html
# Maintainer: Petr Cervinka <pcervinka@suse.com>
# Tags: https://progress.opensuse.org/issues/49031

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
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
