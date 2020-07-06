# SUSE's openQA tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Packagekit updates using kde applet
# Maintainer: mkravec <mkravec@suse.com>

use base "x11test";
use strict;
use warnings;
use utils;
use testapi;
use x11utils qw(ensure_unlocked_desktop turn_off_kde_screensaver);
use power_action_utils 'power_action';

# Update with Plasma applet for software updates using PackageKit

sub setup_system {
    select_console 'x11', await_console => 0;
    ensure_unlocked_desktop;
    turn_off_kde_screensaver;
}


sub run {
    my ($self) = @_;
    setup_system;

    my @updates_installed_tags = qw(updates_none updates_available updates_available-tray );
    assert_screen [qw(updates_available-tray tray-without-updates-available)];
    if (match_has_tag 'updates_available-tray') {
        assert_and_click("updates_available-tray");

        # First update package manager, then packages, then bsc#992773 (2x)
        while (1) {
            assert_and_click_until_screen_change('updates_click-install');

            # Wait until installation starts, intended to time out
            wait_still_screen(stilltime => 4, timeout => 5);

            # Wait until installation is done
            assert_screen \@updates_installed_tags, 3600;
            # Make sure the applet has fetched the current status from the backend
            # and has finished redrawing. In case the update status changed after
            # the assert_screen, record a soft failure
            wait_still_screen;

            #Check if the applet reports that a restart is needed.
            if (check_screen 'updates_installed-restart') {
                assert_and_click 'updates_installed-restart', 5;
                $self->wait_boot;
                setup_system;
                # Look again
                assert_screen \@updates_installed_tags;
            }
            wait_still_screen;
            if (match_has_tag('updates_none')) {
                if (check_screen 'updates_none', 30) {
                    last;
                } else {
                    record_soft_failure 'boo#992773';
                }
            } elsif (match_has_tag('updates_available')) {
                # look again
                if (check_screen 'updates_none', 0) {
                    record_soft_failure 'boo#1041112';
                    last;
                }
            }
            # Check, if there are more updates available
            elsif (match_has_tag('updates_available-tray')) {
                # look again
                if (check_screen 'updates_available-tray', 30) {
                    assert_and_click("updates_available-tray");
                } else {
                    # Make sure, that there are no updates, otherwise fail
                    assert_screen 'updates_none';
                    record_soft_failure 'boo#1041112';
                    last;
                }
            }
        }
        # Close tray updater
        send_key("alt-f4");
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->upload_packagekit_logs;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
