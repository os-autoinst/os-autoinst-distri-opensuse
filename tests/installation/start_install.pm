# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify installation starts and is in progress
# - If install type is upgrade, handle conflict solution screen, license popup,
# package selection, automatic changes
# - If is standard installation, handle license popup
# - If LIVECD, NICEVIDEO, UPGRADE are not defined or VIDEOMODE=text, monitor
# install progress
# - If USEIMAGES is set, check desktop install type (either kde, gnome or
# textmode)
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use lockapi;
use testapi;
use Utils::Architectures;
use Utils::Backends;
use mmapi;
use version_utils qw(is_sle is_upgrade);

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
    }
    elsif (get_var("AUTOYAST")) {
        assert_screen("inst-packageinstallationstarted", $started_timeout);
    }
    else {
        wait_still_screen(3);    # wait so alt-i is pressed when installation overview is not being generated
        send_key $cmd{install};
        if (check_var('FAIL_EXPECTED', 'SMALL-DISK')) {
            assert_screen 'installation-proposal-error';
            return;
        }
        wait_screen_change { send_key 'alt-o' } if match_has_tag 'inst-overview-error-found';
        while (check_screen([qw(confirmlicense startinstall activate_flag_not_set)], 20)) {
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
        && !check_var('VIDEOMODE', 'text')
        && (!is_sle('=11-sp4') || !is_s390x || !is_backend_s390x))
    {
        my $counter = 20;
        while ($counter--) {
            send_key $cmd{instdetails};
            last if check_screen 'installation-details-view', 10;
        }
        assert_screen 'installation-details-view';

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
