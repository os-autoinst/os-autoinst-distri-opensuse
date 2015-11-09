use base "x11test";
use strict;
use testapi;

# Case 1248849 - Pidgin: IRC
sub run() {
    my $self        = shift;
    my $CHANNELNAME = "susetesting";
    x11_start_program("pidgin");

    # Create account
    send_key "alt-a";
    sleep 2;
    send_key "spc";
    sleep 2;

    # Choose Protocol "IRC"
    send_key_until_needlematch 'pidgin-protocol-irc', 'down';
    send_key "ret";
    sleep 2;
    send_key "alt-u";
    sleep 1;
    type_string "$CHANNELNAME";
    sleep 2;
    send_key "alt-a";

    # Should create IRC account
    assert_screen 'pidgin-irc-account', 3;

    # Close account manager
    send_key "ctrl-a";
    sleep 2;
    send_key "alt-c";
    sleep 15;    # need time to connect server

    # Warning of spoofing ip may appear
    if (check_screen("pidgin-spoofing-ip", 10)) {
        send_key "alt-tab";
        send_key "ctrl-w", 1;    # close it
    }

    # Join a chat
    send_key "ctrl-c";
    sleep 2;

    type_string "#sledtesting";
    sleep 2;
    send_key "alt-j";

    # Should open sledtesting channel
    assert_screen 'pidgin-irc-sledtesting', 3;

    # Send a message
    send_key "alt-tab";
    type_string "Hello from openQA\n";
    assert_screen 'pidgin-irc-msgsent', 3;
    send_key "ctrl-w";
    sleep 2;

    # Cleaning
    send_key "ctrl-a";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "alt-d";
    sleep 2;
    send_key "alt-d";

    # Should not have any account and show welcome window
    assert_screen 'pidgin-welcome', 3;

    # Exit
    send_key "alt-c";
    sleep 2;
    send_key "ctrl-q";
    sleep 2;
}

1;
# vim: set sw=4 et:
