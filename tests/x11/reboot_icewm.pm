# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot from icewm environment
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    send_key "ctrl-alt-delete";    # reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';
    assert_screen 'icewm_confirm_logout';    # Confirm logout, Logout will close all active applications. Proceed?
    send_key 'alt-o';

    $self->wait_boot;
}

sub test_flags {
    return {milestone => 1};
}
1;

