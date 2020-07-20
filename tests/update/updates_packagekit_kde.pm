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
use power_action_utils qw( power_action);

# Update with Plasma applet for software updates using PackageKit

sub setup_system {
    select_console 'x11', await_console => 0;
    ensure_unlocked_desktop;
    turn_off_kde_screensaver;
}


sub run {
    my ($self) = @_;
    setup_system;

    if (check_screen 'plasma-tray-update-error'){
        record_info 'ERROR', 'Cannot reach repositories';
        die;
    }
    # There are two valid states.  Tray with updates or without.
    my @updates_state_tags = qw(plasma-tray-without-updates plasma-tray-with-updates );
    assert_screen \@updates_state_tags;

    # If there are no updates, the test passe.
    if (match_has_tag 'plasma-tray-with-updates') {
        # There can be a maximum of two updates cycles.
        my $update_count = 0;
        do {{
            # Install the updates.
            assert_and_click("plasma-tray-with-updates");
            assert_and_click_until_screen_change('plasma-updates-click-install');
            $update_count++;

            # Wait until installation starts and finishes.
            while( check_screen 'plasma-tray-installing', 10){
                last if(wait_still_screen(stilltime => 5, timeout => 10));
            }
            save_screenshot;

            #Wait for the installation popup to expire.
            while ( check_screen 'plasma-tray-updates-installed')  {
               last if  wait_still_screen(stilltime => 3, timeout => 6);
            } ;

            #Check if the applet reports that a restart is needed.
            if (check_screen 'plasma-updates_installed-restart') {
                select_console 'root-console';
                power_action('reboot', textmode=>1);
                $self->wait_boot;
                setup_system;
                next;
            }
            save_screenshot;
            
            # Make sure the applet has fetched the current status from the backend
            # and has finished redrawing. In case the update status changed after
            # the assert_screen, record a soft failure
            assert_screen \@updates_state_tags;
            wait_still_screen;
            #Check if "Install new updates" pops up even though there are no updates. (boo#1041112)
            if (match_has_tag 'plasma-tray-with-updates' and check_screen 'plasma-tray-without-updates') {
                record_soft_failure 'boo#1041112';
            }
        }}  while (  check_screen 'plasma-tray-with-updates' and  $update_count < 2);

        if (match_has_tag 'plasma-tray-with-updates') {
            die "Updates should already have been installed";
        }
        assert_screen 'plasma-tray-without-updates';
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->upload_packagekit_logs;
}

sub test_flags {
    return {milestone => 1
                , fatal => 1};
}

1;

