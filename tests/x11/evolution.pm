use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("evolution");
    if (check_screen "evolution-default-client-ask", 20) {
        assert_and_click "evolution-default-client-agree";
    }
    assert_screen 'test-evolution-1', 30;
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
    send_key "alt-f4";
    wait_idle;
}

1;
# vim: set sw=4 et:
