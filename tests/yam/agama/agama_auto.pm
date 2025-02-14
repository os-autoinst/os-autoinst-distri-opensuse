## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Wait for unattended installation to finish,
# reboot and reach login prompt.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;

use testapi;

sub agama_set_root_password {
    wait_still_screen 5;
    send_key 'tab';
    wait_still_screen 5;
    send_key 'tab';
    wait_still_screen 5;
    type_password();
    send_key 'tab';
    wait_still_screen 2;
    send_key 'tab';
    wait_still_screen 2;
    send_key 'ret';
}

sub agama_create_user {
    wait_still_screen 5;

    # We need to click to make screen active
    mouse_set(600, 600);
    mouse_click;

    save_screenshot;
    send_key 'tab';
    type_string 'Bernhard M. Wiedemann';

    send_key 'tab';
    type_string $testapi::username;
    wait_still_screen 5;

    save_screenshot;
    send_key 'tab';
    type_password();
    wait_still_screen 5;
    send_key 'tab';
    send_key 'tab';

    wait_still_screen 5;
    type_password();
    wait_still_screen 5;
    send_key 'tab';
    send_key 'tab';

    # auto log in
    send_key 'spc';
    wait_still_screen 5;
    send_key 'tab';
    send_key 'tab';
    save_screenshot;
    send_key 'ret';
}
sub run {
    my $self = shift;

    # for offline medium installation, we need to maually click to install
    if (get_var("OFFLINE_SUT")) {
        assert_screen('agama-inst-product-list');
        assert_and_click('agama-product-sle16');
        wait_still_screen 3;
        send_key_until_needlematch('agama-inst-license', 'tab');
        send_key 'spc';
        wait_still_screen 3;
        assert_screen('agama-inst-license-selected');
        assert_and_click('agama-product-select');

        assert_screen('agama-configure-product');
        wait_still_screen(timeout => 60);
        # set root passowrd
        assert_screen('agama-set-root-password');
        agama_set_root_password;

        assert_screen('agama-overview-screen');
        assert_and_click('agama-show-tabs');

        # create user
        assert_and_click('agama-users-tab');
        assert_and_click('agama-define-user-button');
        agama_create_user;

        wait_still_screen 3;
        assert_and_click('agama-install-button');
        wait_still_screen 5;

        assert_and_click('agama-continue-installation');
    }
    my $reboot_page = $testapi::distri->get_reboot();
    $reboot_page->expect_is_shown();
    $self->upload_agama_logs();
    $reboot_page->reboot();
}

1;
