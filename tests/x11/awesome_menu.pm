# Summary: awesome window manager startup
#    Based on "minimalx" installation.
# Maintainer: Dominik Heidler <dheidler@suse.de>
# Tags: poo#9522

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    send_key "super-w";
    assert_screen 'test-awesome-menu-1', 3;
    send_key "esc";
}

sub test_flags {
    return {fatal => 1};
}

1;
