# Summary: awesome window manager startup
#    Based on "minimalx" installation.
# Maintainer: Dominik Heidler <dheidler@suse.de>
# Tags: poo#9522

use base "x11test";
use strict;
use warnings;
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
