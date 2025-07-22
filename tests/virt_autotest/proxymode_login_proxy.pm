# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: proxymode_login_proxy: Login to Physical machine thru Proxy machine with ipmitool.
# Maintainer: John <xgwang@suse.com>

use File::Basename;
use base "opensusebasetest";
use testapi;

sub run {
    my ($self) = @_;
    assert_screen "bootloader";
    send_key "ret";
    $self->wait_for_boot_menu(bootloader_time => 10);
    send_key 'ret';
    assert_screen "displaymanager", 300;
    select_console('root-console');
}

sub test_flags {
    return {fatal => 1};
}

1;
