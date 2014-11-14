use base "bigx11step";
use bmwqemu;

sub run() {
    my $self = shift;
    ensure_installed("Mesa-demo-x");
    x11_start_program("glxgears");
    assert_screen 'test-glxgears-1', 3;
    send_key "alt-f4", 1;
    send_key "ret", 1;
    sleep 5;    # time to close
}

1;
# vim: set sw=4 et:
