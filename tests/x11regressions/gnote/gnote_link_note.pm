use base "x11test";
use strict;
use testapi;

# case 1436158-test link in note

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen 'gnote-first-launched', 10;
    send_key "ctrl-n";
    assert_screen 'gnote-new-note',5;
    type_string "Start Here\n";
    assert_screen 'gnote-new-note-link',5;
    send_key "up";
    sleep 2;
    send_key "ctrl-ret";        #switch to link
    assert_screen 'gnote-note-start-here',5;

    send_key "ctrl-tab";        #jump to toolbar
    for ( 1 .. 6 ) { send_key "right" }
    sleep 2;
    send_key "ret";
    send_key "down";
    assert_screen 'gnote-what-link-here',5;
    send_key "esc";
    send_key "ctrl-w";          #close the note "Start Here"
    sleep 2;

    #clean: remove the created new note
    send_key "ctrl-tab";        #jump to toolbar
    sleep 2;
    send_key "ret";             #back to all notes interface
    send_key_until_needlematch 'gnote-new-note-matched', 'down', 6;
    send_key "delete";
    sleep 2;
    send_key "tab";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
