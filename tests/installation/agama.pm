# oSUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation of Leap or Tumblweed with Agama
# https://github.com/openSUSE/agama/

# Setting agama live media root password
# https://github.com/openSUSE/agama/blob/master/doc/live_iso.md#the-access-password
# Maintainer:  Maintainer: Lubos Kocmman <lubos.kocman@suse.com>,

use strict;
use warnings;
use base "installbasetest";
use testapi;
use version_utils qw(is_leap is_sle);
use utils;

sub run {
    my ($self) = @_;

    assert_screen('agama-inst-welcome-product-list');

    if (is_leap('>=16.0')) {
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

	# It seems that in lower resolutions agama hides list of tabs
	# so we have to click on the top button to display them
    # Good thing is that tabs get hiden automatically again
	# after you click one of the tabs
    assert_and_click('agama-show-tabs');

    # default is just a minimal server style install
    if (check_var('DESKTOP', 'gnome')) {
        assert_and_click('agama-software-tab');

        wait_still_screen 5;
        assert_and_click('agama-change-software-selection');
        wait_still_screen 5;
        assert_and_click('agama-software-selection-gnome-desktop-wayland');
        assert_and_click('agama-software-selection-close');
    }

    # TODO fetch agama logs before install (in case of dependency issues, or if further installation crashes)

	# Show tabs again so we can click on overview
	assert_and_click('agama-show-tabs');
    assert_and_click('agama-overview-tab');

	# The ready to install button is at the bottom of the page on lowres screen
    # Normally it's on the side
    wait_still_screen 5;
	# takes you to bottom of the page, but you need to click on the page first
    assert_and_click('agama-install-icon'); # WORKAROUND: not an install-button
	send_key "ctrl-down";

    assert_and_click('agama-install-button');
    # confirmation dialog if we keep default partitioning layout
    assert_and_click('agama-confirm-installation');

    # online-only installation  it might take long based on connectivity
    # We're using wrong repo for testing
    # BUG tracker: https://github.com/openSUSE/agama/issues/1474
	# copied from await_install.pm
    my $timeout = 2400;
    while (1) {
        die "timeout ($timeout) hit on during await_install" if $timeout <= 0;
        my $ret = check_screen 'agama-install-in-progress', 30;
		sleep 30;
        $timeout -= 30;
        diag("left total await_install timeout: $timeout");
        if (!$ret) {
			# Handle any error dialogs that could happen
			last;
		}
	}

    # installation done
    # TODO fetch agama logs after install see https://github.com/openSUSE/agama/issues/1447
    assert_screen('agama-congratulations');
    assert_and_click('agama-reboot-after-install');

}

1;
