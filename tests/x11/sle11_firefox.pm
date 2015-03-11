use base "firefox";
use testapi;

sub start_firefox() {
    x11_start_program("firefox", 6, { valid => 1 } );
    assert_screen 'test-firefox-1', 60;
    if (check_var('DESKTOP', 'kde')) {
        # uncheck Always perform default browser check, firefox audio without default browser check
        send_key 'alt-y';   # accept firefox as default browser
    }
}

1;
# vim: set sw=4 et:
