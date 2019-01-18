# Summary: Test for xterm started in awesome window manager
# Maintainer: Dominik Heidler <dheidler@suse.de>
# Tags: poo#9522

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    send_key "super-r";
    type_string "xterm\n";
    assert_screen 'awesome_xterm_icon', 10;
    type_string "clear\n";
    $self->enter_test_text('xterm');
    assert_screen 'test-xterm-1', 5;
    send_key "super-shift-c";
}

sub test_flags {
    return {fatal => 1};
}

1;
