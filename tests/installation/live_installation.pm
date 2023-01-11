# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add test for live installer based on Kde-Live
#  The live installer was missing for some time from the media and the left overs
#  in tests showed to be out of date. Changing all necessary references to ensure
#  the live medium can be booted, the net installer can be run from the plasma
#  session and the installed Tumbleweed system boots correctly. In the process an
#  issue with the live installer has been found and is worked around while
#  recording a reference to the bug.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use warnings;
use testapi;
use utils;
use version_utils "is_upgrade";
use strict;
use warnings;
use x11utils 'turn_off_kde_screensaver';
use Utils::Architectures;

sub send_key_and_wait {
    my ($key, $wait_time) = @_;
    $wait_time //= 1;
    send_key $key;
    wait_still_screen($wait_time);
}

sub run {
    if (get_netboot_mirror) {
        select_console 'install-shell';
        # Force use of the matching repo
        assert_script_run("sed -i'' 's#ZyppRepoURL:.*\$#ZyppRepoURL: " . get_netboot_mirror . "#g' /usr/sbin/start-install.sh");
        select_console 'x11';
    }

    # stop packagekit, root password is not needed on live system
    x11_start_program('systemctl stop packagekit.service', target_match => 'generic-desktop');
    turn_off_kde_screensaver;
    if (is_upgrade) {
        if (is_aarch64) {
            # On aarch64 there is sporadic issue when "Upgrade" icon is clicked too long,
            # so that overlay appeared instead of opening the wizard.
            x11_start_program('xdg-su -c "/usr/sbin/start-install.sh upgrade"', target_match => 'maximize');
        }
        else {
            assert_and_click 'live-upgrade';
        }
    }
    else {
        if (is_aarch64) {
            # On aarch64 there is sporadic issue when "Install" icon is clicked too long,
            # so that overlay appeared instead of opening the wizard.
            x11_start_program('xdg-su -c "/usr/sbin/start-install.sh"', target_match => 'maximize');
        }
        else {
            assert_and_click 'live-installation';
        }
    }
    assert_and_click 'maximize';
    mouse_hide;
    # Wait until the first screen is shown, only way to make sure it's idle
    assert_screen ["inst-welcome", "inst-betawarning"], 180;
    # To fully reuse installer screenshots we set to fullscreen. Unfortunately
    # it seems no default shortcut is configured in plasma but we can use the
    # window context menu.

    if (match_has_tag 'inst-betawarning') {
        # Right click at the top to not set the beta warning to fullscreen.
        # This seems to hit a bug in KWin in 15.0 though,
        # so only use if necessary.
        mouse_set 100, 0;
        mouse_click 'right';
        mouse_hide;
    }
    else {
        send_key 'alt-f3';
    }
    assert_screen 'context-menu-more_actions';
    # more
    send_key_and_wait 'alt-m';
    assert_screen 'more_actions-fullscreen_opt';
    # fullscreen
    send_key_and_wait 'alt-f';
    assert_screen 'fullscreen-mode-information_dialog', 180;
    send_key 'ret';
    save_screenshot;
}

1;
