# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: awesome
# Summary: awesome window manager startup
#    Based on "minimalx" installation.
# Maintainer: Dominik Heidler <dheidler@suse.de>
# Tags: poo#9522

use base "x11test";
use testapi;

sub run {
    # Make sure we can see all the menu - poo#50192
    mouse_set(30, 30);

    send_key_until_needlematch "test-awesome-menu-1", "super-w";
    send_key "esc";

    # Hide the mouse again
    mouse_hide();
}

sub test_flags {
    return {fatal => 1};
}

1;
