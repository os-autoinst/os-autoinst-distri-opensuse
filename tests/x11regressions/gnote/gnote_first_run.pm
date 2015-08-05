use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 10;

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
