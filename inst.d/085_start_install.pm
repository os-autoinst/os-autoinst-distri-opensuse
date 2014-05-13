#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub run() {
    my $self = shift;

    # start install
    if ( $envs->{UPGRADE} ) {
        send_key $cmd{update};
        sleep 1;
        my $ret = assert_screen  [qw/startupdate startupdate-conflict/], 5 ;

        while ( $ret->{needle}->has_tag("startupdate-conflict") ) {
            $self->take_screenshot;
            send_key $cmd{ok}, 1;

            send_key $cmd{change}, 1;
            send_key $cmd{"package"}, 1;
            assert_screen  "package-conflict", 5 ;
            $self->take_screenshot;
            send_key "alt-1", 1;    # We hope that zypper makes the best suggestion here
            send_key $cmd{ok}, 1;

            assert_screen  "package-resolve-conflict", 5 ;
            send_key $cmd{accept}, 1;

            assert_screen  "automatic-changes", 5 ;
            send_key $cmd{"continue"}, 1;

            send_key $cmd{update};
            sleep 1;
            $ret = assert_screen  [qw/startupdate startupdate-conflict/], 5 ;
        }

        # confirm
        assert_screen 'startupdate';
        send_key $cmd{update};

        if (check_screen('ERROR-bootloader_preupdate', 3)) {
	   send_key 'alt-n';
	   ++$self->{dents};
	}
        assert_screen "inst-packageinstallationstarted";
        # view installation details
        send_key $cmd{instdetails};
    }
    else {
        send_key $cmd{install};
        assert_screen "startinstall";

        # confirm
        send_key $cmd{install};
        assert_screen "inst-packageinstallationstarted";
    }
    if ( !$envs->{LIVECD} && !$envs->{NICEVIDEO} && !$envs->{UPGRADE} && !checkEnv( 'VIDEOMODE', 'text' ) ) {
        while (1) {
            my $ret = check_screen  [ 'installation-details-view', 'inst-bootmenu', 'grub2' ], 3 ;
            if ( defined($ret) ) {
                last if $ret->{needle}->has_tag("installation-details-view");
                # intention to let this test fail
                assert_screen  'installation-details-view', 1  if ( $ret->{needle}->has_tag("inst-bootmenu") || $ret->{needle}->has_tag("grub2") );
            }
            send_key $cmd{instdetails};
        }
        if ( $envs->{DVD} && !$envs->{NOIMAGES} ) {
            if ( checkEnv( 'DESKTOP', 'kde' ) ) {
                assert_screen  'kde-imagesused', 500 ;
            }
            elsif ( checkEnv( 'DESKTOP', 'gnome' ) ) {
                assert_screen  'gnome-imagesused', 500 ;
            }
            elsif ( !checkEnv( "DESKTOP", "textmode" ) ) {
                assert_screen  'x11-imagesused', 500 ;
            }
        }
    }
}

1;
# vim: set sw=4 et:
