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
    sendautotype("$USERNAME");
    sleep 2;
    send_key "shift-2";
    sleep 2;
    sendautotype("$DOMAIN");
    sleep 2;
    send_key "dot";
    sleep 1;
    sendautotype("com");
    sleep 2;
    send_key "alt-p";
    sleep 1;
    sendautotype("$PASSWD");
    sleep 2;
    send_key "alt-a";
    waitidle;
    sleep 45;    # Connect to MSN are very slow
                 # Should create MSN account
    $self->check_screen;

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
    sendautotype("hello world!\n");
    sleep 2;
    waitidle;
    sleep 10;

    # Should see "hello world!" in screen.
    $self->check_screen;

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
    $self->check_screen;

    # Exit
    send_key "alt-c";
    sleep 2;
    send_key "ctrl-q";
    sleep 2;
}

1;
# vim: set sw=4 et:
