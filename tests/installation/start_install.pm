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
use version_utils 'is_upgrade';

sub check_bsc982138 {
    if (check_screen('installation-details-view-remaining-time-gt2h', 5)) {
        record_soft_failure 'bsc#982138: Remaining time estimation during installation shows >2h most of the time';
    }
}

sub run {
    # start install
    # we need to wait a bit for the disks to be formatted, live cd
    # installation seems to be exceptionally slow.
    # Also, virtual machines for testing can be really slow in this step
    my $started_timeout = get_var('LIVECD') ? 1200 : 300;
    if (is_upgrade) {
        send_key $cmd{update};
        sleep 1;
        assert_screen [qw(startupdate startupdate-conflict license-popup)], 5;

        while (match_has_tag("startupdate-conflict") || match_has_tag("license-popup")) {
            if (match_has_tag("startupdate-conflict")) {
                send_key $cmd{ok};

                while (!check_screen('packages-section-selected', 2)) {
                    send_key 'tab';
                }

                assert_and_click 'packages-section-selected';
                assert_screen "package-conflict";

                while (!check_screen('all-conflicts-resolved-packages', 4)) {
                    assert_and_click 'package-conflict-choice';
                    send_key $cmd{ok};
                    wait_still_screen 10;
                }
                send_key $cmd{accept};

                while (check_screen('license-popup', 2)) {
                    send_key $cmd{accept};
                }
                assert_screen "automatic-changes";
                send_key $cmd{continue};

                send_key $cmd{update};
                sleep 1;
            }
            if (match_has_tag("license-popup")) {
                send_key $cmd{accept};
            }
            assert_screen [qw(startupdate startupdate-conflict license-popup)], 5;
        }

        # confirm
        assert_screen 'startupdate';
        send_key $cmd{update};
        assert_screen "inst-packageinstallationstarted", $started_timeout;

        # view installation details
        send_key $cmd{instdetails};
        check_bsc982138;
    }
    elsif (get_var("AUTOYAST")) {
        assert_screen("inst-packageinstallationstarted", $started_timeout);
    }
    else {
        sleep 2;    # textmode is sometimes pressing alt-i too early
        send_key $cmd{install};
        wait_screen_change { send_key 'alt-o' } if match_has_tag('inst-overview-error-found', 0);
        while (check_screen([qw(confirmlicense startinstall activate_flag_not_set)], 5)) {
            last if match_has_tag("startinstall");
            if (match_has_tag("confirmlicense")) {
                send_key $cmd{acceptlicense};
            }
            else {
                send_key 'alt-o';
            }
        }
        assert_screen "startinstall";

        # confirm
        send_key $cmd{install};
        assert_screen "inst-packageinstallationstarted", $started_timeout;
    }
    if (!get_var("LIVECD")
        && !get_var("NICEVIDEO")
        && !get_var("UPGRADE")
        && !check_var('VIDEOMODE', 'text'))
    {
        my $counter = 20;
        while ($counter--) {
            send_key $cmd{instdetails};
            last if check_screen 'installation-details-view', 10;
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

