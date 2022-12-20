# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-settings-daemon gdm
# Summary: testcase 5255-1503905: Gnome:gnome-login test
#   other login scenario has been covered by the change_password
#   script, here only cover the auto_login
# - Start gnome-settings, unlock user settings
# - Enable auto-login and reboot
# - Disable auto-login
# Maintainer: xiaojun <xjin@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use power_action_utils 'power_action';

sub auto_login_alter {
    my ($self) = @_;
    $self->unlock_user_settings;
    send_key "alt-u";
    send_key "alt-f4";
}

sub run {
    my ($self) = @_;

    assert_screen "generic-desktop";
    $self->auto_login_alter;
    my $ov = get_var('NOAUTOLOGIN');
    if (!$ov) {
        set_var('NOAUTOLOGIN', 1);
    }
    else {
        set_var('NOAUTOLOGIN', '');
    }
    power_action('reboot');
    $self->wait_boot(bootloader_time => 300);
    set_var('NOAUTOLOGIN', $ov);
    $self->auto_login_alter;
}

1;
