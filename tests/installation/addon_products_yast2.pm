# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: add addon to SLES via DVD or URL
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base qw(y2_installbase y2_module_guitest);
use strict;
use warnings;
use testapi;
use power_action_utils 'reboot_x11';
use registration qw(fill_in_registration_data skip_registration);

sub run {
    my ($self) = @_;
    my ($addon, $uc_addon);
    my $perform_reboot;
    $self->launch_yast2_module_x11('add-on', target_match => [qw(addon-products packagekit-warning)]);
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
            $uc_addon = uc $addon;    # varibale name is upper case
            assert_screen 'inst-addon';
            if (check_var('SCC_REGISTER', 'network')) {
                send_key 'alt-u';     # specify url
                send_key $cmd{next};
                assert_screen 'addonurl-entry', 3;
                type_string get_var("ADDONURL_$uc_addon");
                send_key 'alt-p';     # name
                type_string "SLE$uc_addon" . get_var('VERSION') . "_repo";
                send_key $cmd{next};
            }
            else {
                wait_screen_change { send_key 'alt-v' };    # DVD
                send_key $cmd{next};
                assert_screen 'dvd-selector',                        3;
                send_key_until_needlematch 'addon-dvd-list',         'tab', 5;      # jump into addon list
                send_key_until_needlematch "addon-dvd-sr$sr_number", 'down', 10;    # select addon in list
                send_key 'alt-o';                                                   # continue
            }
            if (check_screen('import-untrusted-gpg-key', 10)) {                     # workaround untrusted key pop-up, record soft fail and trust it
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
            wait_screen_change { send_key 'alt-a' };                                # yes, agree
            send_key $cmd{next};
            assert_screen 'addon-yast2-patterns';
            send_key_until_needlematch 'addon-yast2-view-selected', 'alt-v', 10;
            send_key 'spc';                                                         # open view menu
            wait_screen_change { send_key 'alt-r' };
            wait_screen_change { send_key 'alt-r' };                                # go to repositories
            send_key 'ret';                                                         # open repositories tab
            assert_screen "addon-yast2-repo-$addon";
            send_key 'alt-a';                                                       # accept
            assert_screen 'automatic-changes';
            send_key 'alt-o';                                                       # OK
            my @needles = qw(unsupported-package addon-installation-pop-up addon-installation-report);
            do {
                assert_screen \@needles, 300;
                if (match_has_tag('unsupported-packages')) {
                    die 'unsupported packages';
                    send_key 'alt-o';
                }
                if (match_has_tag('addon-installation-pop-up')) {
                    $perform_reboot = 1;
                    send_key 'alt-o';
                }
            } until (match_has_tag('addon-installation-report'));
            wait_screen_change { send_key 'alt-f'; }    # finish
            send_key 'alt-a';                           # accept
            assert_screen 'scc-registration';
            if (get_var('SCC_REGISTER')) {
                fill_in_registration_data;
                if ($addon ne 'sdk') {                  # sdk doesn't ask for code
                    my $regcode = get_var("SCC_REGCODE_$uc_addon");
                    assert_screen "addon-reg-code";
                    send_key 'tab';                     # jump to code field
                    type_string $regcode;
                    sleep 1;
                    save_screenshot;
                    send_key $cmd{next};
                }
                assert_screen 'addon-products', 60;
                wait_screen_change { send_key "tab" };    # select addon-products-$addon
                send_key "pgup",                                    1;
                send_key_until_needlematch "addon-products-$addon", 'down';
            }
            else {
                skip_registration;
                if (check_screen("scc-skip-base-system-reg-warning", 30)) {
                    wait_screen_change { send_key "alt-y" };    # confirmed skip SCC registration
                }
            }
            if ((split(/,/, get_var('ADDONS')))[-1] ne $addon) {    # if $addon is not first from all ADDONS
                send_key 'alt-a';                                   # add another add-on
            }
            else {
                send_key 'alt-o';                                   # ok continue
            }
        }
        if (defined $perform_reboot) {
            reboot_x11;
            $self->wait_boot;
        }
    }
    else {
        send_key 'alt-n';                                           # done
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};                            # add milestone flag to save setup in lastgood VM snapshot
}

1;
