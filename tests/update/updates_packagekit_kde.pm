# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: PackageKit plasma5-pk-updates
# Summary: Packagekit updates using kde applet
# Maintainer: mkravec <mkravec@suse.com>

use base "x11test";
use strict;
use warnings;
use utils;
use testapi;
use x11utils qw(ensure_unlocked_desktop turn_off_kde_screensaver);
use power_action_utils qw(power_action);

# Update with Plasma applet for software updates using PackageKit
sub run {
    my ($self) = @_;
    select_console 'x11', await_console => 0;
    ensure_unlocked_desktop;
    turn_off_kde_screensaver;
    my @updates_installed_tags = qw(updates_none updates_available updates_available-tray);
    assert_screen [qw(updates_available-tray tray-without-updates-available)];
    if (match_has_tag 'updates_available-tray') {
        # First update package manager, then packages, then bsc#992773 (2x)
        while (1) {
            assert_screen_change {
                assert_and_click_until_screen_change("updates_available-tray");
            };
            assert_screen_change {
                assert_and_click_until_screen_change('updates_click-install', 10, 5);
            };

            # Wait until installation is done.
            my $start_time = time;
            my $timeout = 3600 * get_var('TIMEOUT_SCALE', 1);
            do {
                # Check for needles matching the end of the update installation.
                die "Installing updates took over " . ($timeout / 3600) . " hour(s)." if (time - $start_time > $timeout);
                assert_screen \@updates_installed_tags, 3600;
                # Make sure that the match was not false, and that the installing panel is not still up
            } while (check_screen([qw(pkit_installing_state updates_waiting)]));
            # Make sure the applet has fetched the current status from the backend
            # and has finished redrawing. In case the update status changed after
            # the assert_screen, record a soft failure
            wait_still_screen;
            if (match_has_tag('updates_none')) {
                if (check_screen 'updates_none', 30) {
                    last;
                }
                else {
                    record_soft_failure 'boo#992773';
                }
            }
            elsif (match_has_tag('updates_available')) {
                # look again
                if (check_screen 'updates_none', 0) {
                    record_soft_failure 'boo#1041112';
                    last;
                }
            }
            # Check, if there are more updates available
            elsif (match_has_tag('updates_available-tray')) {
                # Look again
                if (check_screen 'updates_none', 30) {
                    # There were no updates but the tray icon persisted.
                    record_soft_failure 'boo#1041112';
                    last;
                }
                elsif (check_screen 'updates_available-tray', 30) {
                    # There were updates. Do the update again
                    next;
                }
                else {
                    die "Invalid state.";
                }
            }
        }
        # Close tray updater
        send_key("alt-f4");
    }

    if (check_screen "updates_installed-restart") {
        assert_screen_change {
            assert_and_click_until_screen_change "plasma-updates_installed-restart"
        }
        power_action 'reboot', {observe => 1};
        $self->wait_boot;
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
