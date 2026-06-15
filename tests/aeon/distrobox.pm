# SUSE's openQA tests
#
# Copyright SUSE LLC and contributors
# SPDX-License-Identifier: FSFAP

# Summary: Test Aeon distrobox

# Maintainer: Jan-Willem Harmannij <jwharmannij at gmail com>

use Mojo::Base 'basetest';
use testapi;
use utils;

sub run {
    # Open GNOME Shell overview
    unless (check_screen 'gnome-shell-overview') {
        send_key 'super';
        assert_screen 'gnome-shell-overview';
    }

    # Start GNOME Console
    type_string 'console';
    assert_screen 'gnome-console-icon';
    send_key 'ret';
    assert_screen 'gnome-console-open';

    # Create and enter distrobox
    type_string('distrobox create', lf => 1);
    assert_screen 'distrobox-created', 600;

    type_string('distrobox enter', lf => 1);
    assert_screen 'distrobox-successful', 600;

    # Exit distrobox and Console
    type_string('exit', lf => 1);
    type_string('exit', lf => 1);
}

1;
