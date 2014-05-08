use base "basetest";
use strict;
use bmwqemu;

# test tomboy: open
# testcase 1248874

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;

    # open start note and take screenshot
    x11_start_program("tomboy note");
    send_key "alt-f11";
    sleep 2;
    send_key "ctrl-home";
    sleep 2;
    sendautotype "Rename_";
    sleep 1;
    send_key "ctrl-w";
    waitidle;

    # Check hotkey for open "start here" still works
    send_key "alt-fll";
    sleep 2;
    waitstillimage;
    checkneedle( "tomboy_open_0", 5 );

    send_key "shift-up";
    sleep 2;
    send_key "delete";
    sleep 2;
    send_key "ctrl-w";
    sleep 2;
    send_key "alt-f4";
    sleep 2;

    # logout
    send_key "alt-f2";
    sleep 1;
    sendautotype "gnome-session-quit --logout --force\n";
    sleep 20;
    waitidle;

    # login
    send_key "ret";
    sleep 2;
    waitstillimage;
    sendpassword();
    sleep 2;
    send_key "ret";
    sleep 20;
    waitidle;

    # open start note again and take screenshot
    x11_start_program("tomboy note");
    send_key "alt-f11";
    sleep 2;
    send_key "up";
    sleep 1;
    checkneedle( "tomboy_open_1", 5 );
    send_key "ctrl-w";
    sleep 2;
    send_key "alt-f4";
    sleep 2;
    waitidle;
}

1;
# vim: set sw=4 et:
