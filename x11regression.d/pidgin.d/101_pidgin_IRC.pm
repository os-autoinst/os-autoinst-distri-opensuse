use base "basetest";
use bmwqemu;

# Case 1248849 - Pidgin: IRC

my $IRC         = 7;
my $CHANNELNAME = "susetesting";

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
    waitidle;
    sleep 10;

    # Should create IRC account
    $self->check_screen;

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
    waitidle;
    sleep 10;

    # Should open sledtesting channel
    $self->check_screen;

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
