
use strict;
use base "installstep";
use bmwqemu;

sub run() {
    my $self = shift;

    if ( $vars{ENCRYPT} ) {
        wait_encrypt_prompt;
    }

    mouse_hide();

    assert_screen( 'displaymanager', 200 );
    if ( check_var( 'DESKTOP', 'minimalx' ) ) {
        type_string($username);
    }
    send_key("ret");
    wait_idle;
    type_string("$password");
    send_key("ret");

    assert_screen( "desktop-at-first-boot", 40 );

    if ( check_var( 'DESKTOP', 'kde' ) ) {
        send_key "esc";
        sleep 2;
        $self->take_screenshot();
    }
}

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1, 'milestone' => 1 };
}

1;
