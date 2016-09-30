# G-Summary: Add test for awesome window manager
#    Based on "minimalx" installation.
#
#    Related issue: https://progress.opensuse.org/issues/9522
# G-Maintainer: Dominik Heidler <dheidler@suse.de>

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    send_key "super-w";
    assert_screen 'test-awesome-menu-1', 3;
    send_key "esc";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
