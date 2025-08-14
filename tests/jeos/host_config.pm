# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# JeOS with kernel-default-base doesn't use kms, so the default mode
# 1024x768 of the cirrus kms driver doesn't help us. We need to
# manually configure grub to tell the kernel what mode to use.

# Summary: Configure MinimalVM images
# Maintainer: Michal Nowak <mnowak@suse.com>

use Mojo::Base qw(opensusebasetest);
use testapi;
use serial_terminal;
use jeos qw(set_grub_gfxmode);
use utils qw(ensure_serialdev_permissions);
use Utils::Architectures qw(is_s390x);
use version_utils qw(is_sle);

sub run {
    select_console('root-console');

    set_grub_gfxmode;
    ensure_serialdev_permissions;
    prepare_serial_console;
    if (is_s390x && is_sle('16.0+')) {
        my $uuid = script_output(q[nmcli -t -f UUID,TYPE c show --active | awk -F\: '/ethernet/ { print $1 }']);
        assert_script_run "nmcli c modify $uuid ipv6.addr-gen-mode eui64";
        assert_script_run "nmcli c down $uuid && nmcli c up $uuid";
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
