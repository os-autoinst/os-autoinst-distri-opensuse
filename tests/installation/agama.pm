# oSUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation of Leap or Tumbleweed with Agama
# https://github.com/openSUSE/agama/

# Setting agama live media root password
# https://github.com/openSUSE/agama/blob/master/doc/live_iso.md#the-access-password

# This test suite handles basic installation of Leap and Tumbleweed with Agama
# Actions past install-screen with reboot button ara handled separately in agama_reboot.pm
# Maintainer: Lubos Kocman <lubos.kocman@suse.com>,

use strict;
use warnings;
use base "installbasetest";
use testapi;
use version_utils qw(is_leap is_sle);
use utils;
use Utils::Logging qw(export_healthcheck_basic);
use x11utils 'ensure_unlocked_desktop';

sub agama_set_root_password_dialog {
    wait_still_screen 5;

    type_password();
    send_key 'tab';    # show password btn
    send_key 'tab';
    wait_still_screen 5;
    type_password();
    send_key 'tab';
    send_key 'tab';    # show password btn
    send_key 'ret';
}

sub agama_define_user_screen {
    wait_still_screen 5;

    # We need to click in the middle of the screen or similar
    # to make screen active so we can start typing.
    # This is not the case in e.g. root password dialog which gets auto active
    mouse_set(600, 600);
    mouse_click;


    # Fullname
    send_key 'tab';
    type_string 'Bernhard M. Wiedemann';

    # Username
    send_key 'tab';
    type_string $testapi::username;
    wait_still_screen 5;

    # Password - we have to send two tabs as there is a button to show typed password
    send_key 'tab';
    type_password();
    wait_still_screen 5;
    send_key 'tab';    # show password btn
    send_key 'tab';

    wait_still_screen 5;
    type_password();
    wait_still_screen 5;
    send_key 'tab';    # show password btn
    send_key 'tab';

    # Autologin
    if (!get_var("NOAUTOLOGIN")) {
        send_key 'spc';    # checkbox
        wait_still_screen 5;
    }

    send_key 'tab';    # Cancel btn
    send_key 'tab';    # Accept btn
    send_key 'ret';
}

sub upload_agama_logs {
    return if (get_var('NOLOGS'));
    select_console("root-console");
    # stores logs in /tmp/agma-logs.tar.gz
    script_run('agama logs store');
    upload_logs('/tmp/agama-logs.tar.gz');
}

sub get_agama_install_console_tty {
    # get_x11_console_tty would otherwise autodetermine 2
    return 7;
}

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

    # It seems that in lower resolutions agama hides list of tabs
    # so we have to click on the top button to display them
    # Good thing is that tabs get hidden automatically again
    # after you click one of the tabs
    assert_and_click('agama-show-tabs');

    assert_and_click('agama-users-tab');
    assert_and_click('agama-set-root-password');
    agama_set_root_password_dialog();


    # Define user and set autologin on
    assert_and_click('agama-define-user-button');
    agama_define_user_screen();

    # Show tabs again
    assert_and_click('agama-show-tabs');

    # default is just a minimal server style install
    if (get_var('DESKTOP')) {
        assert_and_click('agama-software-tab');

        wait_still_screen(5);
        assert_and_click('agama-change-software-selection');
        wait_still_screen(5);

        if (check_var('DESKTOP', 'gnome')) {
            assert_and_click('agama-software-selection-gnome-desktop-wayland');
        } elsif (check_var('DESKTOP', 'kde')) {
            assert_and_click('agama-software-selection-kde-desktop-wayland');
        }

        assert_and_click('agama-software-selection-close');
    }

    # TODO fetch agama logs before install (in case of dependency issues, or if further installation crashes)

    # Show tabs again so we can click on overview
    assert_and_click('agama-show-tabs');
    assert_and_click('agama-overview-tab');

    # The ready to install button is at the bottom of the page on lowres screen
    # Normally it's on the side
    wait_still_screen 5;

    # Ctrl+down takes you to bottom of the page,
    # however, you need to click on the page first
    mouse_set(600, 600);
    mouse_click;
    send_key "ctrl-down";

    assert_and_click('agama-install-button');
    # confirmation dialog if we keep default partitioning layout
    assert_and_click('agama-confirm-installation');

    # online-only installation  it might take long based on connectivity
    # We're using wrong repo for testing
    # BUG tracker: https://github.com/openSUSE/agama/issues/1474
    # copied from await_install.pm
    my $timeout = 2400;    # 40 minutes timeout for installation process
    while (1) {
        die "timeout ($timeout) hit during await_install" if $timeout <= 0;
        my $ret = check_screen 'agama-install-in-progress', 30;
        sleep 30;
        $timeout -= 30;
        diag("left total await_install timeout: $timeout");
        if (!$ret) {
            # Handle any error dialogs that could happen
            last;
        }
    }
}

=head2 post_fail_hook

 post_fail_hook();

When the test module fails, this method will be called.
It will try to fetch logs from agama.

=cut

sub post_fail_hook {
    my ($self) = @_;

    return if (get_var('NOLOGS'));

    select_console("root-console");
    export_healthcheck_basic();
    upload_agama_logs();
}


1;
