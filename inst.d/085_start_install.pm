#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub run() {
    my $self = shift;

    # start install
    if ( $ENV{UPGRADE} ) {
        send_key $cmd{update};
        sleep 1;
        my $ret = waitforneedle( [qw/startupdate startupdate-conflict/], 5 );

        while ( $ret->{needle}->has_tag("startupdate-conflict") ) {
            $self->take_screenshot;
            send_key $cmd{ok}, 1;

            send_key $cmd{change}, 1;
            send_key $cmd{"package"}, 1;
            waitforneedle( "package-conflict", 5 );
            $self->take_screenshot;
            send_key "alt-1", 1;    # We hope that zypper makes the best suggestion here
            send_key $cmd{ok}, 1;

            waitforneedle( "package-resolve-conflict", 5 );
            send_key $cmd{accept}, 1;

            waitforneedle( "automatic-changes", 5 );
            send_key $cmd{"continue"}, 1;

            send_key $cmd{update};
            sleep 1;
            $ret = waitforneedle( [qw/startupdate startupdate-conflict/], 5 );
        }

        # confirm
        $self->take_screenshot;
        send_key $cmd{update};

        sleep 5;

        # view installation details
        send_key $cmd{instdetails};
    }
    else {
        send_key $cmd{install};
        waitforneedle("startinstall");

        # confirm
        $self->take_screenshot;
        send_key $cmd{install};
        waitforneedle("inst-packageinstallationstarted");
    }
    if ( !$ENV{LIVECD} && !$ENV{NICEVIDEO} && !$ENV{UPGRADE} && !checkEnv( 'VIDEOMODE', 'text' ) ) {
        while (1) {
            my $ret = checkneedle( [ 'installation-details-view', 'inst-bootmenu', 'grub2' ], 3 );
            if ( defined($ret) ) {
                last if $ret->{needle}->has_tag("installation-details-view");
                # intention to let this test fail
                waitforneedle( 'installation-details-view', 1 ) if ( $ret->{needle}->has_tag("inst-bootmenu") || $ret->{needle}->has_tag("grub2") );
            }
            send_key $cmd{instdetails};
        }
        if ( $ENV{DVD} && !$ENV{NOIMAGES} ) {
            if ( checkEnv( 'DESKTOP', 'kde' ) ) {
                waitforneedle( 'kde-imagesused', 500 );
            }
            elsif ( checkEnv( 'DESKTOP', 'gnome' ) ) {
                waitforneedle( 'gnome-imagesused', 500 );
            }
            elsif ( !checkEnv( "DESKTOP", "textmode" ) ) {
                waitforneedle( 'x11-imagesused', 500 );
            }
        }
    }
}

1;
# vim: set sw=4 et:
