use base "x11test";
use strict;
use testapi;

# case 1436169-rename gnote title

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 10;
    send_key "ctrl-n";
    assert_screen 'gnote-new-note',5;
    send_key "up";
    send_key "up";
    type_string "new title-opensuse\n";
    send_key "ctrl-tab";        #jump to toolbar
    sleep 2;
    send_key "ret";             #back to all notes interface
    sleep 5;                    #it needs seconds to refresh title
    send_key_until_needlematch 'gnote-new-note-title-matched', 'down', 6;
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
