# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure WSL users
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "windowsbasetest";
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub enter_user_details {
    my $creds = shift;
    foreach (@{$creds}) {
        if (defined($_)) {
            wait_still_screen stilltime => 1, timeout => 5;
            wait_screen_change { type_string "$_", max_interval => 125, wait_screen_change => 2 };
            wait_screen_change { send_key((is_sle) ? 'ret' : 'tab') };
            wait_still_screen stilltime => 3, timeout => 10;
        } else {
            wait_screen_change { send_key((is_sle) ? 'ret' : 'tab') };
            next;
        }
    }
}

sub run {
    #0) WSL installation is in progress
    assert_and_click 'install-linux-in-wsl', timeout => 120;
    assert_screen [qw(yast2-wsl-firstboot-welcome wsl-installing-prompt)], 240;

    if (match_has_tag 'yast2-wsl-firstboot-welcome') {
        assert_and_click 'window-max';
        wait_still_screen stilltime => 3, timeout => 10;
        send_key 'alt-n';
        # license agreement
        assert_screen 'wsl-license';
        send_key 'alt-n';
        assert_screen 'local-user-credentials';
        enter_user_details([$realname, undef, $password, $password]);
        send_key 'alt-n';
        assert_screen 'wsl-installation-completed', 60;
        send_key 'alt-f';
        assert_screen 'wsl-linux-prompt';
        wait_screen_change { type_string 'exit' };
        send_key 'ret';
        save_screenshot;
    } else {
        #1) skip registration, we cannot register against proxy SCC
        assert_and_click 'window-max';
        assert_screen 'wsl-registration-prompt', 300;
        send_key 'ret';

        #2) enter user credentials
        assert_screen 'wsl-image-setup-enter-username', 120;
        enter_user_details([$username, $password, $password]);
        assert_screen 'wsl-image-setup-use-password-for-root', 120;
        wait_screen_change { type_string 'y' };
        sleep 2;
        send_key 'ret';
        assert_screen 'wsl-image-ready-prompt', 120;
        wait_screen_change { type_string 'exit' };
        send_key 'ret';
        sleep 2;
        save_screenshot;
    }
}

1;
