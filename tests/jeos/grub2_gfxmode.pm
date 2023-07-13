# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# JeOS with kernel-default-base doesn't use kms, so the default mode
# 1024x768 of the cirrus kms driver doesn't help us. We need to
# manually configure grub to tell the kernel what mode to use.

# Summary: Set GRUB_GFXMODE to 1024x768
# Maintainer: Michal Nowak <mnowak@suse.com>

use Mojo::Base qw(opensusebasetest);
use testapi;
use serial_terminal 'select_serial_terminal';
use jeos qw(set_grub_gfxmode);

sub run {
    select_serial_terminal;

    set_grub_gfxmode;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
