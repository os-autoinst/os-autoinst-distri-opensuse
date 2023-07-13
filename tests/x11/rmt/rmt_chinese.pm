# SUSE's openQA tests
#
# Copyright 2021-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-rmt rmt-server
# Summary: rmt-cli internationalization / localization test (only test Chinese)
# Steps: 1. Set language to simply Chinese.
#        2. Install and configure RMT server, ensure the configuration process
#           in Chinese.
#        3. Run rmt-cli sync and ensure the output is in Chinese.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use testapi;
use base 'x11test';
use repo_tools;
use utils;
use x11utils;
use version_utils;

sub set_language_to_Chinese {
    if (check_var('DESKTOP', 'gnome')) {
        select_console 'root-console';
        turn_off_gnome_screensaver_for_gdm;
    }
    select_console 'x11', await_console => 0;
    wait_still_screen 15;
    ensure_unlocked_desktop;
    assert_screen 'generic-desktop';

    x11_start_program('xterm');
    wait_still_screen 2, 2;
    become_root;
    script_run('yast2 language', die_on_timeout => 0);
    assert_screen 'yast2-language', 60;
    send_key_until_needlematch 'yast2-lang-simplified-chinese', 'down', 181;
    send_key 'alt-o';

    # Problem here is that sometimes installation takes longer than 10 minutes
    # And then screen saver is activated, so add this step to wake
    my $timeout = 0;
    until (check_screen('generic-desktop', 30) || ++$timeout > 10) {
        # Now it will install required language packages and exit
        # Put in the loop, because sometimes button is not pressed
        wait_screen_change { send_key 'alt-o'; };
        sleep 60;
        send_key 'ctrl';
    }

    # Logout and login to ensure the configuration for Chinese language take effect.
    handle_relogin;

    # Reserve old folder name and close dialog of requirement for language change to update folder
    assert_screen 'language-change-required-update-folder';
    assert_and_click('reserve_old_folder_name');
    assert_screen 'generic-desktop';

    x11_start_program('gnome-terminal');
    wait_still_screen 2, 2;
    become_root;
}

sub run {
    set_language_to_Chinese;

    rmt_wizard();
    rmt_sync;

    # Check output is chinese
    assert_screen 'rmt_sync_finished';

    # Close the terminal
    send_key 'alt-f4';
    if (check_screen('close-terminal-warning-dialog', 30)) {
        send_key 'alt-l';
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
