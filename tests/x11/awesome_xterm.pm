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
    send_key "super-r";
    type_string "xterm\n";
    assert_screen 'awesome_xterm_icon', 10;
    type_string "clear\n";
    my $arbitrary_newlines = 13;
    for (1 .. $arbitrary_newlines) { send_key "ret" }
    type_string "echo If you can see this text xterm is working.\n";
    assert_screen 'test-xterm-1', 5;
    send_key "super-shift-c";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
