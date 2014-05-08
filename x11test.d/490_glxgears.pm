use base "basetest";
use bmwqemu;

sub is_applicable {
    return $ENV{BIGTEST} && !$ENV{NICEVIDEO};
}

sub run() {
    my $self = shift;
    ensure_installed("Mesa-demo-x");
    x11_start_program("glxgears");
    $self->check_screen;
    send_key "alt-f4", 1;
    send_key "ret", 1;
    sleep 5;    # time to close
}

1;
# vim: set sw=4 et:
