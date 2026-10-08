# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Reboot from XFCE environment
# Maintainer: Oliver Kurz <okurz@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use x11utils qw(update_x11_vt);

sub run {
    my ($self) = @_;
    send_key "alt-f4";    # open logout dialog
    assert_screen 'logoutdialog', 15;
    send_key "tab";    # reboot
    save_screenshot;
    send_key "ret";    # confirm
    $self->wait_boot;
    update_x11_vt;
}

sub test_flags {
    return {milestone => 1};
}

1;
