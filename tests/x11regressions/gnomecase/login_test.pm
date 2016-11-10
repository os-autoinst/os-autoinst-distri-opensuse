# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: testcase 5255-1503905: Gnome:gnome-login test
#   other login scenario has been coverred by the change_password
#   script, here only cover the auto_login
# Maintainer: xiaojun <xjin@suse.com>

use base "x11regressiontest";
use strict;
use testapi;
use utils;

sub auto_login_alter {
    my ($self) = @_;
    $self->unlock_user_settings;
    send_key "alt-u";
    send_key "alt-f4";
}

sub run () {
    my ($self) = @_;

    assert_screen "generic-desktop";
    $self->auto_login_alter;
    reboot_gnome;
    auto_login_alter;
}

1;
# vim: set sw=4 et:
