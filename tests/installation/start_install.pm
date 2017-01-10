# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify installation starts and is in progress
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub check_bsc982138() {
    if (check_screen('installation-details-view-remaining-time-gt2h', 5)) {
        record_soft_failure 'bsc#982138: Remaining time estimation during installation shows >2h most of the time';
    }
}

sub run() {
    # start install
    if (get_var("UPGRADE")) {
        send_key $cmd{update};
        sleep 1;
        assert_screen [qw(startupdate startupdate-conflict license-popup)], 5;

        while (match_has_tag("startupdate-conflict") || match_has_tag("license-popup")) {
            if (match_has_tag("startupdate-conflict")) {
                send_key $cmd{ok}, 1;

                while (!check_screen('packages-section-selected', 2)) {
                    send_key 'tab';
                }

                assert_and_click 'packages-section-selected';
                assert_screen "package-conflict";

                while (!check_screen('all-conflicts-resolved-packages', 4)) {
                    assert_and_click 'package-conflict-choice';
                    send_key $cmd{ok}, 1;
                }
                send_key $cmd{accept}, 1;

                while (check_screen('license-popup', 2)) {
                    send_key $cmd{accept}, 1;
                }
                assert_screen "automatic-changes";
                send_key $cmd{continue}, 1;

                send_key $cmd{update};
                sleep 1;
            }
            if (match_has_tag("license-popup")) {
                send_key $cmd{accept}, 1;
            }
            assert_screen [qw(startupdate startupdate-conflict license-popup)], 5;
        }

        # confirm
        assert_screen 'startupdate';
        send_key $cmd{update};

        if (check_screen('ERROR-bootloader_preupdate', 3)) {
            send_key 'alt-n';
            record_soft_failure 'error bootloader preupdate';
        }
        assert_screen "inst-packageinstallationstarted", 120;

        # view installation details
        send_key $cmd{instdetails};
        check_bsc982138;
    }
    elsif (get_var("AUTOYAST")) {
        assert_screen("inst-packageinstallationstarted", 120);
    }
    else {
        sleep 2;    # textmode is sometimes pressing alt-i too early
        send_key $cmd{install};
        while (check_screen([qw(confirmlicense startinstall)], 5)) {
            last if match_has_tag("startinstall");
            send_key $cmd{acceptlicense}, 1;
        }
        assert_screen "startinstall";

        # confirm
        send_key $cmd{install};
        # we need to wait a bit for the disks to be formatted, live cd
        # installation seems to be exceptionally slow
        my $started_timeout = get_var('LIVECD') ? 600 : 120;
        assert_screen "inst-packageinstallationstarted", $started_timeout;
    }
    if (   !get_var("LIVECD")
        && !get_var("NICEVIDEO")
        && !get_var("UPGRADE")
        && !check_var('VIDEOMODE', 'text'))
    {
        my $counter = 10;
        while ($counter--) {
            send_key $cmd{instdetails};
            last if check_screen 'installation-details-view', 5;
        }
        assert_screen 'installation-details-view';
        check_bsc982138;

        if (get_var("USEIMAGES")) {
            if (check_var('DESKTOP', 'kde')) {
                assert_screen 'kde-imagesused', 500;
            }
            elsif (check_var('DESKTOP', 'gnome')) {
                assert_screen 'gnome-imagesused', 500;
            }
            elsif (!check_var("DESKTOP", "textmode")) {
                assert_screen 'x11-imagesused', 500;
            }
        }
    }
}

1;

# vim: set sw=4 et:
