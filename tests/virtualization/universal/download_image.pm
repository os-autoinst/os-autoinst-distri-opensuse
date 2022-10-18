# SUSE's openQA tests

# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rsync
# Summary: Download disk image
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    ensure_default_net_is_active();

    script_run "if [ -d \"/mnt/virt_images\" ]; then umount /mnt/virt_images; else mkdir /mnt/virt_images; fi";
    assert_script_run "mount " . get_var('VIRT_IMAGE_PATH') . " /mnt/virt_images";

    # Pull images from server if necessary
    zypper_call("install rsync", exitcode => [0, 102, 103, 106]) if (script_run("which rsync") != 0);
    assert_script_run "if [ ! -f \"$virt_autotest::common::imports{$_}->{disk}\" ]; then rsync -v --progress $virt_autotest::common::imports{$_}->{source} $virt_autotest::common::imports{$_}->{disk}; fi", 600 foreach (keys %virt_autotest::common::imports);

    assert_script_run "umount /mnt/virt_images";
}

1;
