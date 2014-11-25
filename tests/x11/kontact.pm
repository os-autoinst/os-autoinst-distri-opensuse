use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    # start akonadi server avoid self-test running when launch kontact
    x11_start_program("akonadictl start");
    wait_idle 3;

    # Workaround: sometimes the account assistant behind of mainwindow or tips window
    # To disable it run at first time start
    x11_start_program("echo \"[General]\" >> ~/.kde4/share/config/kmail2rc");
    x11_start_program("echo \"first-start=false\" >> ~/.kde4/share/config/kmail2rc");
    sleep 2;
    x11_start_program("kontact", 6, { valid => 1 } );

    # assert_screen "kontact-assistant", 20;
    assert_screen "test-kontact-1", 20;    # tips window or assistant
    send_key "alt-f4";
    assert_screen "kontact-window", 3;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
