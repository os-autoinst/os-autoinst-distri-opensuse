# oSUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation of Leap or Tumblweed with Agama
# https://github.com/openSUSE/agama/
# Maintainer:  Maintainer: Lubos Kocmman <lubos.kocman@suse.com>,

use strict;
use warnings;
use testapi;
use version_utils qw(is_leap is_sle);


sub run {
    my ($self) = @_;

    assert_screen('agama-inst-welcome-product-list');

    if (is_leap('=16')) {
        assert_and_click('agama-product-leap16');
        assert_and_click('agama-product-select');
    } else {    # Default to TW
        assert_and_click('agama-product-tumbleweed');
        assert_and_click('agama-product-select');
    }

    # can take few minutes to get here
    assert_screen('agama-overview-screen');

    assert_and_click('agama-defining-user');
    assert_and_click('agama-set-root-password');
    wait_still_screen 5;
    # type password,  tab tab, repeat password, tab tab, enter
    type_password();
    send_key 'tab';
    send_key 'tab';
    wait_still_screen 5;
    type_password();
    send_key 'tab';
    send_key 'tab';
    send_key 'ret';

    # default is just a minimal server style install
    if (check_var('DESKTOP', 'gnome')) {
        assert_and_click('agama-software-tab');
        wait_still_screen 5;
        assert_and_click('agama-change-software-selection');
        wait_still_screen 5;
        assert_and_click('agama-software-selection-gnome-desktop-wayland');
    }

    # TODO fetch agama logs before install (in case of dependency issues, or if further installation crashes)

    # all set, start installation
    assert_and_click('agama-overview-tab');
    assert_and_click('agama-ready-for-installation');

    # confirmation dialog if we keep default partitioning layout
    assert_and_click('agama-confirm-installation');

    # online-only installation  it might take long based on connectivity
    # We're using wrong repo for testing
    # BUG tracker: https://github.com/openSUSE/agama/issues/1474

    # installation done
    # TODO fetch agama logs after install see https://github.com/openSUSE/agama/issues/1447
    assert_screen('agama-congratulations');
    assert_and_click('agama-reboot-after-install');

}

1;
