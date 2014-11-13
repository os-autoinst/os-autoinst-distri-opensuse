use strict;
use base "y2logsstep";
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

sub post_fail_hook() {
    my $self = shift;

    send_key "ctrl-alt-f2";
    assert_screen("text-login", 10);
    type_string "root\n";
    sleep 2;
    sendpassword; type_string "\n";
    sleep 1;

    save_screenshot;

    type_string "cat /home/*/.xsession-errors* > /tmp/XSE\n";
    upload_logs "/tmp/XSE";
    save_screenshot;

    type_string "journalctl -b > /tmp/journal\n";
    upload_logs "/tmp/journal";
    save_screenshot;

    type_string "cat /var/log/X* > /tmp/Xlogs\n";
    upload_logs "/tmp/Xlogs";
    save_screenshot;
}

1;

# vim: set sw=4 et:
