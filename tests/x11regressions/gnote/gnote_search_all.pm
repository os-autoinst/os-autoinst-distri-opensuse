use base "x11test";
use strict;
use testapi;

# case 1436174-test function search all notes

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 10;
    send_key "ctrl-f";
    sleep 2;
    type_string "welcome";
    assert_screen 'gnote-search-welcome', 5;

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
