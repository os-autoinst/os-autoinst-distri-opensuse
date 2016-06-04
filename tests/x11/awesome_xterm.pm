use base "x11test";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;
    send_key "super-r";
    type_string "xterm\n";
    assert_screen_with_soft_timeout('awesome_xterm_icon', soft_timeout => 10);
    type_string "clear\n";
    my $arbitrary_newlines = 13;
    for (1 .. $arbitrary_newlines) { send_key "ret" }
    type_string "echo If you can see this text xterm is working.\n";
    assert_screen_with_soft_timeout('test-xterm-1', soft_timeout => 5);
    send_key "super-shift-c";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
