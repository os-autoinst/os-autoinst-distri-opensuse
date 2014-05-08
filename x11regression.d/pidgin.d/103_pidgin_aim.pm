use base "basetest";
use bmwqemu;

# Case 1248855 - Pidgin: Add AIM Account
# Case 1248856 - Pidgin: Login to AIM Account and Send/Receive Message

my $AIM       = 0;
my $USERNAME  = "nooops_test3";
my $USERNAME1 = "nooops_test4";
my $DOMAIN    = "aim";
my $PASSWD    = "opensuse";

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

    # Choose Protocol "AIM",which is by default
    #send_key "spc";
    #sleep 2;
    #foreach(1..$AIM){
    #        send_key "down";
    #        sleep 1;
    #}
    #send_key "ret"; sleep 2;
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
    sleep 15;

    # Should create AIM account 1
    $self->check_screen;

    # Create another account
    send_key "ctrl-a";
    sleep 2;
    send_key "alt-a";
    sleep 2;
    send_key "alt-u";
    sleep 1;
    sendautotype("$USERNAME1");
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
    sleep 15;

    # Should have AIM accounts 1 and 2
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

    # Remove one account
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

    # Remove the other account
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
