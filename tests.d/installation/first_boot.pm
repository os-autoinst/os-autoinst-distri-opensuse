use strict;
use base "y2logsstep";
use bmwqemu;

sub run() {
    my $self = shift;

    if ( $vars{ENCRYPT} ) {
        wait_encrypt_prompt;
    }

    #if($vars{RAIDLEVEL} && !$vars{LIVECD}) { do "$scriptdir/workaround/656536.pm" }
    #assert_screen "automaticconfiguration", 70;
    mouse_hide();

    if ( $vars{'NOAUTOLOGIN'} ) {
        assert_screen 'displaymanager', 200;
        type_string $username;
        send_key "ret";
        type_string "$password";
        send_key "ret";
    }

    # Check for errors during first boot
    my $err  = 0;
    my $timeout = 400;
    my @tags = qw/desktop-at-first-boot install-failed/;
    while (1) {
        my $ret = assert_screen \@tags, $timeout;
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
            $timeout = 30; # decrease timeout to 30 seconds
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

    mydie if $err;
}

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1, 'milestone' => 1 };
}

1;

# vim: set sw=4 et:
