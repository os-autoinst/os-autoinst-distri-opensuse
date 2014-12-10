use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    mouse_hide();

    if ( get_var("NOAUTOLOGIN") ) {
        assert_screen 'displaymanager', 200;
        if ( get_var('DM_NEEDS_USERNAME') ) {
            type_string $username;
        }
        send_key "ret";
        wait_idle;
        type_string "$password";
        send_key "ret";
    }

    # Check for errors during first boot
    my $err  = 0;
    my @tags = qw/desktop-at-first-boot install-failed/;
    while (1) {
        my $ret = assert_screen \@tags, 400;
        if ( $ret->{needle}->has_tag("desktop-at-first-boot") && !check_var( "DESKTOP", "kde" ) ) {
            last;
        }
        elsif ( $ret->{needle}->has_tag("desktop-at-first-boot") && check_var( "DESKTOP", "kde" ) ) {
            # a special case for KDE greeter
            wait_idle 5;
            send_key "esc"; # close the KDE greeter
            sleep 3;
            push( @tags, "generic-desktop" );
            push( @tags, "drkonqi-crash" );
            @tags = grep { $_ ne 'desktop-at-first-boot' } @tags;
            next;
        }
        elsif ( $ret->{needle}->has_tag("generic-desktop") ) {
            last;
        }
        elsif ( $ret->{needle}->has_tag("drkonqi-crash") ) {
            # handle for KDE greeter crashed and drkonqi popup
            send_key "alt-d";

            # maximize
            send_key "alt-shift-f3";
            sleep 8;
            save_screenshot;
            send_key "alt-c";
            @tags = grep { $_ ne 'drkonqi-crash' } @tags;
            next;
        }

        save_screenshot;
        sleep 2;
        send_key "ret";
        $err = 1;
        last if $err;
    }

    die 'failed' if $err;
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
    type_password;
    type_string "\n";
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
