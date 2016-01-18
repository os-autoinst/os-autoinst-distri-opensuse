use base "x11test";
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

1;
# vim: set sw=4 et:
