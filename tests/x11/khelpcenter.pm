use base "kdestep";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("khelpcenter", 6, { valid => 1 } );
    if ( get_var("LIVETEST") ) {
        assert_screen 'test-khelpcenter-1', 15;
    }
    else {
        assert_screen 'test-khelpcenter-1', 3;
    }
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
