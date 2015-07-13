#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # start install
    if ( get_var("UPGRADE") ) {
        send_key $cmd{update};
        sleep 1;
        my $ret = assert_screen [qw/startupdate startupdate-conflict license-popup/], 5;

        while ( $ret->{needle}->has_tag("startupdate-conflict") || $ret->{needle}->has_tag("license-popup") ) {
            if ( $ret->{needle}->has_tag("startupdate-conflict") ) {
                send_key $cmd{ok}, 1;

                while ( !check_screen( 'packages-section-selected', 2 ) ) {
                    send_key 'tab';
                }

                assert_and_click 'packages-section-selected';
                assert_screen "package-conflict", 20;

                while ( !check_screen( 'all-conflicts-resolved-packages', 4 ) ) {
                    assert_and_click 'package-conflict-choice';
                    send_key $cmd{ok}, 1;
                }
                send_key $cmd{"accept"}, 1;

                while ( check_screen( 'license-popup', 2 ) ) {
                    send_key $cmd{"accept"}, 1;
                }
                assert_screen "automatic-changes", 5;
                send_key $cmd{"continue"}, 1;

                send_key $cmd{update};
                sleep 1;
            }
            if ( $ret->{needle}->has_tag("license-popup") ) {
                send_key $cmd{"accept"}, 1;
            }
            $ret = assert_screen [qw/startupdate startupdate-conflict license-popup/], 5;
        }

        # confirm
        assert_screen 'startupdate';
        send_key $cmd{update};

        if ( check_screen( 'ERROR-bootloader_preupdate', 3 ) ) {
            send_key 'alt-n';
            record_soft_failure;
        }
        assert_screen "inst-packageinstallationstarted";

        # view installation details
        send_key $cmd{instdetails};
    }
    elsif ( get_var("AUTOYAST") ) {
        assert_screen( "inst-packageinstallationstarted", 120 );
    }
    else {
        send_key $cmd{install};
        while ( my $ret = check_screen( [qw/confirmlicense startinstall/], 5 ) ) {
            last if $ret->{needle}->has_tag("startinstall");
            send_key $cmd{acceptlicense}, 1;
        }
        assert_screen "startinstall";

        # confirm
        send_key $cmd{install};
        # we need to wait a bit for the disks to be formatted
        assert_screen "inst-packageinstallationstarted", 120;
    }
    if (   !get_var("LIVECD")
        && !get_var("NICEVIDEO")
        && !get_var("UPGRADE")
        && !check_var( 'VIDEOMODE', 'text' ) )
    {
        while (1) {
            my $ret = check_screen [ 'installation-details-view', 'grub2' ], 3;
            if ( defined($ret) ) {
                last if $ret->{needle}->has_tag("installation-details-view");

                # intention to let this test fail
                assert_screen 'installation-details-view', 1
                  if $ret->{needle}->has_tag("grub2");
            }
            send_key $cmd{instdetails};
        }
        if ( get_var("DVD") && !get_var("NOIMAGES") ) {
            if ( check_var( 'DESKTOP', 'kde' ) ) {
                assert_screen 'kde-imagesused', 500;
            }
            elsif ( check_var( 'DESKTOP', 'gnome' ) ) {
                assert_screen 'gnome-imagesused', 500;
            }
            elsif ( !check_var( "DESKTOP", "textmode" ) ) {
                assert_screen 'x11-imagesused', 500;
            }
        }
    }
}

1;

# vim: set sw=4 et:
