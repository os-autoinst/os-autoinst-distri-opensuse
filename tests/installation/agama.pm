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

use base "installbasetest";
use testapi;
use version_utils qw(is_leap is_sle is_microos);
use utils;
use Utils::Logging qw(export_healthcheck_basic);
use Utils::Architectures;
use x11utils 'ensure_unlocked_desktop';

sub back_to_overview {
    assert_and_click('agama-overview-tab');
    wait_still_screen 5;
    record_info('Back to overview');
}

# A More complex screen for root auth
sub agama_set_root_password_screen {
    wait_still_screen 5;

    # a new toggle to enable password auth for root
    assert_and_click('agama-use-root-password');
    wait_still_screen 5;

    send_key 'tab';    # to switch from toggle to input box
    type_password();
    send_key 'tab';    # show password btn
    send_key 'tab';
    wait_still_screen 5;
    type_password();
    send_key 'tab';    # show password btn
    send_key 'tab';    # optional enable public ssh key toggle
    send_key 'tab';    # accept button
    save_screenshot;
    send_key 'ret';
}

sub agama_define_user_screen {
    wait_still_screen 5;

    # We need to click in the middle of the screen or similar
    # to make screen active so we can start typing.
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
    send_key 'tab';    # show password btn
    send_key 'tab';
    type_password();

    # Autologin - Please use NOAUTOLOGIN for now, regression on agama 12
    # https://github.com/agama-project/agama/issues/2143
    #if (!get_var("NOAUTOLOGIN")) {
    #    send_key 'spc';    # checkbox
    #    wait_still_screen 5;
    #}

    assert_and_click('agama-user-accept-button');
    wait_still_screen 5;
}

sub agama_fde_setup {
    assert_and_click('agma-storage-tab');
    wait_still_screen 5;
    assert_and_click('agama-encryption-tab');
    assert_and_click('agama-encryption-change');
    assert_and_click('agama-FDE-enable');
    send_key 'tab';
    type_password();
    send_key 'tab';
    send_key 'tab';
    type_password();
    save_screenshot;
    send_key 'ret';
    wait_still_screen 5;
    assert_screen('agama-fde-enabled');
}

sub agama_lvm_setup {
    assert_and_click('agma-storage-tab');
    assert_and_click('agama-use-vda-to-install');
    assert_and_click('agama-create-lvm-on-vda');
    wait_still_screen 5;
    mouse_set(630, 300);
    mouse_click;    # click on a blank portion, so we can scroll down with the keyboard
    send_key_until_needlematch('agama-lvm-proposal', 'ctrl-down');
}

sub upload_agama_logs {
    return if (get_var('NOLOGS'));
    select_console("root-console");
    # stores logs in /tmp/agma-logs.tar.gz
    script_run('agama logs store');
    upload_logs('/tmp/agama-logs.tar.gz');
}


sub select_product {
    # Product selection dialog scrolls with 4+ products at 1024x768.
    # As of now TW is the last item in the list, so we need to scroll a bit.
    mouse_set(600, 600);
    mouse_click;

    my $product_to_install = "agama-product-tumbleweed";
    $product_to_install = "agama-product-leap16" if is_leap;
    $product_to_install = "agama-product-microos" if is_microos;

    if (is_leap('>=16.0')) {
        send_key_until_needlematch($product_to_install, 'down');
        assert_and_click($product_to_install);
    } else {    # Default to TW
        send_key_until_needlematch($product_to_install, 'down');
        assert_and_click($product_to_install);
        # New agama version has the Select button inside the same container
        # We need to click on an empty space so we can press arrow down
        mouse_set(850, 630);
        mouse_click;
        send_key_until_needlematch('agama-product-select', 'ctrl-down');
    }
    assert_and_click('agama-product-select');
}

sub select_software {
    assert_and_click('agama-software-tab');
    wait_still_screen(5);
    assert_and_click('agama-change-software-selection');
    wait_still_screen(5);

    # pattern selection can be pretty long
    # I suggest to scroll down until you match the needle and then click on it
    # Go to the very top in case (ctrl+up) that you need to look for further patterns

    # Default is just a minimal server style install
    if (get_var('DESKTOP')) {
        if (check_var('DESKTOP', 'gnome')) {
            send_key_until_needlematch('agama-software-selection-gnome-desktop-wayland', 'down');
            assert_and_click('agama-software-selection-gnome-desktop-wayland');
        } elsif (check_var('DESKTOP', 'kde')) {
            send_key_until_needlematch('agama-software-selection-kde-desktop-wayland', 'down');
            assert_and_click('agama-software-selection-kde-desktop-wayland');
        } elsif (check_var('DESKTOP', 'icewm')) {
            send_key_until_needlematch('agama-software-selection-icewm-desktop-wayland', 'down');
            assert_and_click('agama-software-selection-icewm-desktop-wayland');
        }
        # Go back to the top in case that any further patterns need to be installed
        # and we have to scroll through the list again.
        send_key "ctrl-up";
    }

    # Futher manually selected patterns should go here

    assert_and_click('agama-software-selection-close');

}

sub run {
    my ($self) = @_;
    my $agama_screen_timeout = 300;
    if (!is_ppc64le && !is_s390x) {
        assert_screen('agama-inst-welcome-product-list', timeout => $agama_screen_timeout);
        select_product();
    }

    # can take few minutes to get here
    assert_screen('agama-overview-screen', timeout => $agama_screen_timeout);

    # clicking on agama-show-tab seems to be no longer needed
    # on low-res screens
    assert_and_click('agama-auth-tab');
    assert_and_click('agama-set-root-password');
    agama_set_root_password_screen();


    # Define user and set autologin on
    assert_and_click('agama-define-user-button');
    agama_define_user_screen();

    # TODO fetch agama logs before install (in case of dependency issues, or if further installation crashes)

    back_to_overview;

    # Install additional patterns
    select_software();
    wait_still_screen 5;

    # The ready to install button is at the bottom of the page on lowres screen
    # Normally it's on the side

    back_to_overview;

    if (check_var('LVM', 1)) {
        agama_lvm_setup();
        back_to_overview;
    }

    if (check_var('ENCRYPT', 1)) {
        agama_fde_setup();
        back_to_overview;
    }

    assert_and_click('agama-install-button');

    # confirmation dialog if we keep default partitioning layout
    assert_and_click('agama-confirm-installation');

    # ensure that the installation started before matching agama-congratulations
    # https://github.com/openSUSE/agama/issues/1616
    assert_screen('agama-install-in-progress');

    my $timeout = 2400;    # 40 minutes timeout for installation process
                           # Await installation with a timeout
    while ($timeout > 0) {
        my $ret = check_screen('agama-congratulations', 30);
        $timeout -= 30;
        diag("left total await_install timeout: $timeout");
        last if $ret;
        die "timeout ($timeout) hit during await_install" if $timeout <= 0;
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

    select_console("install-shell");
    export_healthcheck_basic();
    upload_agama_logs();
}


1;
