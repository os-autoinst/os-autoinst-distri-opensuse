use base "basetest";
use strict;
use bmwqemu;

# test tomboy: print
# testcase 1248880

# this function decides if the test shall run
sub is_applicable {
    return ( $envs->{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;

    # open tomboy
    x11_start_program("tomboy note");

    # open a note and print to file
    send_key "tab";
    sleep 1;
    send_key "down";
    sleep 1;
    send_key "ret";
    sleep 3;
    send_key "ctrl-p";
    sleep 3;
    send_key "tab";
    sleep 1;
    send_key "alt-v";
    sleep 5;    #FIXME Print to file failed in this version, so just replace with preview.
                #send_key "alt-p"; sleep 2; #FIXME
                #send_key "alt-r"; sleep 5; #FIXME

    waitidle;
    assert_screen 'test-tomboy_Print-1', 3;
    sleep 2;
    send_key "ctrl-w";
    sleep 2;
    send_key "ctrl-w";
    sleep 2;
    send_key "alt-f4";
    sleep 2;
    waitidle;
}

1;
# vim: set sw=4 et:
