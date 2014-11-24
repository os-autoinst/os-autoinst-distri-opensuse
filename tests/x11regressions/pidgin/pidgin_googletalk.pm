use base "basetest";
use testapi;

# Case 1248850 - Pidgin: Google talk

my $GOOGLETALK = 4;
my $USERNAME   = "nooops6";
my $PASSWD     = "opensuse";

sub run() {
    my $self = shift;
    x11_start_program("pidgin");
    wait_idle;
    sleep 2;

    # Create account
    send_key "alt-a";
    sleep 2;
    send_key "spc";
    sleep 2;

    # Choose Protocol "GOOGLETALK"
    foreach ( 1 .. $GOOGLETALK ) {
        send_key "down";
        sleep 1;
    }
    send_key "ret";
    sleep 2;
    send_key "alt-u";
    sleep 1;
    type_string "$USERNAME";
    sleep 2;
    send_key "alt-p";
    sleep 1;
    type_string "$PASSWD";
    sleep 2;
    send_key "alt-a";
    wait_idle;
    sleep 15;

    # Should create GoogleTalk account
    assert_screen 'test-pidgin_googletalk-1', 3;

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
    wait_idle;
    sleep 10;

    # Should see "hello world!" in screen.
    assert_screen 'test-pidgin_googletalk-2', 3;

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
    wait_idle;
    sleep 2;

    # Should not have any account
    assert_screen 'test-pidgin_googletalk-3', 3;

    # Exit
    send_key "alt-c";
    sleep 2;
    send_key "ctrl-q";
    sleep 2;
}

1;
# vim: set sw=4 et:
