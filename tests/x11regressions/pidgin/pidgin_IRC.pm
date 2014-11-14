use base "basetest";
use bmwqemu;

# Case 1248849 - Pidgin: IRC

my $IRC         = 7;
my $CHANNELNAME = "susetesting";

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

    # Choose Protocol "IRC"
    foreach ( 1 .. $IRC ) {
        send_key "down";
        sleep 1;
    }
    send_key "ret";
    sleep 2;
    send_key "alt-u";
    sleep 1;
    type_string "$CHANNELNAME";
    sleep 2;
    send_key "alt-a";
    wait_idle;
    sleep 10;

    # Should create IRC account
    assert_screen 'test-pidgin_IRC-1', 3;

    # Close account manager
    send_key "ctrl-a";
    sleep 2;
    send_key "alt-c";
    sleep 2;

    # Join a chat
    send_key "ctrl-c";
    sleep 2;

    # input "#"
    send_key "shift-3";
    sleep 2;
    type_string "sledtesting";
    sleep 2;
    send_key "alt-j";
    wait_idle;
    sleep 10;

    # Should open sledtesting channel
    assert_screen 'test-pidgin_IRC-2', 3;

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
    wait_idle;
    sleep 2;

    # Should not have any account
    assert_screen 'test-pidgin_IRC-3', 3;

    # Exit
    send_key "alt-c";
    sleep 2;
    send_key "ctrl-q";
    sleep 2;
}

1;
# vim: set sw=4 et:
