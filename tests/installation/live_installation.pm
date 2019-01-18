# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add test for live installer based on Kde-Live
#  The live installer was missing for some time from the media and the left overs
#  in tests showed to be out of date. Changing all necessary references to ensure
#  the live medium can be booted, the net installer can be run from the plasma
#  session and the installed Tumbleweed system boots correctly. In the process an
#  issue with the live installer has been found and is worked around while
#  recording a reference to the bug.
#
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use testapi;
use utils;
use version_utils "is_upgrade";
use strict;
use warnings;

sub send_key_and_wait {
    my ($key, $wait_time) = @_;
    $wait_time //= 1;
    send_key $key;
    wait_still_screen($wait_time);
}

sub run {
    # stop packagekit, root password is not needed on live system
    x11_start_program('systemctl stop packagekit.service', target_match => 'generic-desktop');
    turn_off_kde_screensaver;
    if (is_upgrade) {
        assert_and_click 'live-upgrade';
    }
    else {
        assert_and_click 'live-installation';
    }
    assert_and_click 'maximize';
    mouse_hide;
    # Wait until the first screen is shown, only way to make sure it's idle
    assert_screen ["inst-welcome", "inst-betawarning"], 180;
    # To fully reuse installer screenshots we set to fullscreen. Unfortunately
    # it seems no default shortcut is configured in plasma but we can use the
    # window context menu. Right click at the top to not set the beta warning
    # to fullscreen.
    mouse_set 100, 0;
    mouse_click 'right';
    mouse_hide;
    assert_screen 'context-menu-more_actions';
    # more
    send_key_and_wait 'alt-m';
    # fullscreen
    send_key_and_wait 'alt-f';
    assert_screen 'fullscreen-mode-information_dialog', 180;
    send_key 'ret';
    save_screenshot;
}

1;
