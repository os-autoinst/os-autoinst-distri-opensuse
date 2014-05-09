use base "basetest";
use bmwqemu;

# Case 1248853 - Pidgin: Add MSN Account
# Case 1248854 - Pidgin: Login to MSN and Send/Receive message

my $MSN      = 8;
my $USERNAME = "nooops_test2";
my $DOMAIN   = "hotmail";
my $PASSWD   = "OPENsuse";

sub is_applicable() {
    return $ENV{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;
    x11_start_program("pidgin");
    waitidle;
    sleep 2;

    # Create account
    send_key "alt-a";
    sleep 2;

    # Choose Protocol "MSN"
    send_key "spc";
    sleep 2;
    foreach ( 1 .. $MSN ) {
        send_key "down";
        sleep 1;
    }
    send_key "ret";
    sleep 2;
    send_key "alt-u";
    sleep 1;
    type_string "$USERNAME";
    sleep 2;
    send_key "shift-2";
    sleep 2;
    type_string "$DOMAIN";
    sleep 2;
    send_key "dot";
    sleep 1;
    type_string "com";
    sleep 2;
    send_key "alt-p";
    sleep 1;
    type_string "$PASSWD";
    sleep 2;
    send_key "alt-a";
    waitidle;
    sleep 45;    # Connect to MSN are very slow
                 # Should create MSN account
    assert_screen 'test-pidgin_msn-1', 3;

    # Close account manager
    send_key "ctrl-a";
    sleep 2;
    send_key "alt-c";
    sleep 2;

    # Open a chat
    send_key "tab";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "ret";
    sleep 2;
    type_string "hello world!\n";
    sleep 2;
    waitidle;
    sleep 10;

    # Should see "hello world!" in screen.
    assert_screen 'test-pidgin_msn-2', 3;

    # Cleaning
    # Close the conversation
    send_key "ctrl-w";
    sleep 2;
    send_key "ctrl-a";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "alt-d";
    sleep 2;
    send_key "alt-d";
    waitidle;
    sleep 2;

    # Should not have any account
    assert_screen 'test-pidgin_msn-3', 3;

    # Exit
    send_key "alt-c";
    sleep 2;
    send_key "ctrl-q";
    sleep 2;
}

1;
# vim: set sw=4 et:
