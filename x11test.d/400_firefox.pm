use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("firefox");
    $self->check_screen;
    if ( $ENV{UPGRADE} ) { send_key "alt-d"; waitidle; }    # dont check for updated plugins
    if (0) {                                                # 4.0b10 changed default value - b12 has showQuitWarning
        send_key "ctrl-t";
        sleep 1;
        type_string "about:config\n";
        sleep 1;
        send_key "ret";
        waitidle;
        type_string "showQuit\n\t";
        sleep 1;
        send_key "ret";
        waitidle;
        send_key "ctrl-w";
        sleep 1;
    }

    # just leave it here, then don't need modify test-firefox-2 and test-firefox-3
    # tag in all related needles
    $self->check_screen;
    send_key "alt-h";
    sleep 2;    # Help
    send_key "a";
    sleep 2;    # About
    $self->check_screen;
    send_key "alt-f4";
    sleep 2;    # close About
    send_key "alt-f4";
    sleep 2;
    send_key "ret";    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
