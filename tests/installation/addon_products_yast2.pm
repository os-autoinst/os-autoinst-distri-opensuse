# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: add addon to SLES via DVD or URL
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base qw(y2_installbase y2_module_guitest);
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';
use power_action_utils 'reboot_x11';
use x11utils 'turn_off_gnome_screensaver';
use registration qw(fill_in_registration_data skip_registration register_addons);
use List::MoreUtils 'firstidx';

sub test_setup {
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    become_root;

    my @addon_proxy = ('url: http://' . (is_sle('<15') ? 'server-' : 'all-') . get_var('BUILD_SLE'));
    # Add every used addon to regurl for proxy SCC, sle12 addons can have different build numbers
    if (get_var('ADDONS') && is_sle('<15')) {
        for my $addon (split(/,/, get_var('ADDONS', ''))) {
            my $uc_addon = uc $addon;    # change to uppercase to match variable
            push(@addon_proxy, "\b.$addon-" . get_var("BUILD_$uc_addon"));
        }
    }

    assert_script_run "echo \"@addon_proxy.proxy.scc.suse.de\" > /etc/SUSEConnect";    # Define proxy SCC
    wait_screen_change(sub { enter_cmd "exit" }, 5) for (1 .. 2);
}

sub run {
    my ($self) = @_;
    my ($addon, $uc_addon);
    my $perform_reboot;
    test_setup;
    y2_module_guitest::launch_yast2_module_x11('add-on', target_match => [qw(addon-products packagekit-warning)]);
    if (match_has_tag 'packagekit-warning') {
        send_key 'alt-y';
        assert_screen 'addon-products';
    }
    send_key 'alt-a';    # add add-on
    if (get_var("ADDONS")) {
        # the ISO_X variables must match the ADDONS list
        my $sr_number = 0;
        for my $addon (split(/,/, get_var('ADDONS'))) {
            $sr_number++;
            $uc_addon = uc $addon;    # variable name is upper case
            assert_screen 'inst-addon';
            if (check_var('SCC_REGISTER', 'network')) {
                send_key 'alt-u';    # specify url
                send_key $cmd{next};
                assert_screen 'addonurl-entry', 3;
                type_string get_var("ADDONURL_$uc_addon");
                send_key 'alt-p';    # name
                type_string "SLE$uc_addon" . get_var('VERSION') . "_repo";
                send_key $cmd{next};
            }
            else {
                wait_screen_change { send_key 'alt-v' };    # DVD
                send_key $cmd{next};
                assert_screen 'dvd-selector', 3;
                send_key_until_needlematch 'addon-dvd-list', 'tab', 6;    # jump into addon list
                send_key_until_needlematch "addon-dvd-sr$sr_number", 'down', 11;    # select addon in list
                send_key 'alt-o';    # continue
            }
            if (check_screen('import-untrusted-gpg-key', 10)) {    # workaround untrusted key pop-up, record soft fail and trust it
                record_info 'untrusted key', 'Workaround untrusted key by accepting it', result => 'softfail';
                send_key 'alt-t';
            }
            if (get_var("BETA_$uc_addon")) {
                assert_screen "addon-betawarning-$addon";
                send_key "ret";
                assert_screen "addon-license-beta";
            }
            else {
                assert_screen "addon-license-$addon";
            }
            # accept addon license and move to patterns selection
            wait_screen_change { send_key 'alt-a' };    # yes, agree
            send_key $cmd{next};
            assert_screen 'addon-yast2-patterns';
            send_key_until_needlematch 'addon-yast2-view-selected', 'alt-v', 11;
            send_key 'spc';    # open view menu
            wait_screen_change { send_key 'alt-r' };
            wait_screen_change { send_key 'alt-r' };    # go to repositories
            send_key 'ret';    # open repositories tab
            assert_screen "addon-yast2-repo-$addon";
            # accept repositories
            send_key 'alt-a';
            # confirm and continue with automatic changes proposal
            assert_screen 'automatic-changes';
            send_key 'alt-o';
            my @needles = qw(unsupported-package addon-installation-pop-up addon-installation-report);
            do {
                assert_screen \@needles, 300;
                if (match_has_tag('unsupported-packages')) {
                    die 'unsupported packages';
                    send_key 'alt-o';
                }
                if (match_has_tag('addon-installation-pop-up')) {
                    # Handle reboot reminder pop up to activate new kernel ( pop up in case of RT extension )
                    $perform_reboot = 1;
                    send_key 'alt-o';
                    # Avoid to match the pop up more than once
                    my $needle_index = firstidx { $_ eq 'addon-installation-pop-up' } @needles;
                    splice(@needles, $needle_index, 1) unless ($needle_index == -1);
                }
            } until (match_has_tag('addon-installation-report'));
            # Installation report, hit Finish button and proceed to SCC registration
            send_key 'alt-f';
            assert_screen 'scc-registration';
            # This part of code should handle registration of the base system and the added extension or module
            # In case of RT testing, registration is not mandatory in test suite(s) executing *YaST2 add-on*
            if (get_var('SCC_REGISTER')) {
                fill_in_registration_data;
                register_addons;
            }
            else {
                skip_registration;
                if (check_screen("scc-skip-base-system-reg-warning", 30)) {
                    wait_screen_change { send_key "alt-y" };    # confirmed skip SCC registration
                }
            }
            if ((split(/,/, get_var('ADDONS')))[-1] ne $addon) {    # if $addon is not first from all ADDONS
                send_key 'alt-a';    # add another add-on
            }
            else {
                send_key 'alt-o';    # ok continue
            }
        }
        if (defined $perform_reboot) {
            reboot_x11;
            $self->wait_boot;
        }
    }
    else {
        send_key 'alt-n';    # done
    }
}

sub test_flags {
    # add milestone flag to save setup in lastgood VM snapshot
    return {fatal => 1, milestone => 1};
}

1;
