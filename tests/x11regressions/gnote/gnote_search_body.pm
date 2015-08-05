use base "x11test";
use strict;
use testapi;

# case 1436174-test function search all notes

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 5;
    send_key_until_needlematch 'gnote-start-here-matched', 'down', 5;
    send_key "ret";
    sleep 2;
    send_key "ctrl-f";
    sleep 2;
    type_string "and";
    assert_screen 'gnote-search-body-and', 5;

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
