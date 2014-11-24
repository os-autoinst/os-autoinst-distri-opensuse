use base "gnomestep";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("application-browser");
    assert_screen 'test-application_browser-1', 3;
    send_key "alt-f4";
    wait_idle;
}

1;
# vim: set sw=4 et:
