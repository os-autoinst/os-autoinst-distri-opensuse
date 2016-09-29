# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: add addon to SLES via DVD or URL
# G-Maintainer: Jozef Pupava <jpupava@suse.com>

use base "y2logsstep";
use strict;
use testapi;
use registration;

sub run() {
    my ($addon, $uc_addon);
    x11_start_program("xdg-su -c '/sbin/yast2 add-on'");
    if ($password) { type_password; send_key "ret", 1; }
    if (check_screen 'packagekit-warning') {
        send_key 'alt-y';    # yes
    }
    assert_screen 'addon-products';
    send_key 'alt-a', 2;     # add add-on
    if (get_var("ADDONS")) {
        for my $addon (split(/,/, get_var('ADDONS'))) {
            $uc_addon = uc $addon;    # varibale name is upper case
            assert_screen 'inst-addon';
            if (check_var('SCC_REGISTER', 'network')) {
                send_key 'alt-u';     # specify url
                send_key $cmd{next};
                assert_screen 'addonurl-entry', 3;
                type_string get_var("ADDONURL_$uc_addon");
                send_key 'alt-p';     # name
                type_string "SLE$uc_addon" . "12-SP1_repo";
                send_key $cmd{next};
            }
            else {
                send_key 'alt-v', 3;    # DVD
                send_key $cmd{next}, 3;
                assert_screen 'dvd-selector',                  3;
                send_key_until_needlematch 'addon-dvd-list',   'tab', 10;     # jump into addon list
                send_key_until_needlematch "addon-dvd-$addon", 'down', 10;    # select addon in list
                send_key 'alt-o';                                             # continue
            }
            if (check_screen('import-untrusted-gpg-key', 10)) {               # workaround untrusted key pop-up, record soft fail and trust it
                record_soft_failure;
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
            send_key 'alt-a', 2;                                              # yes, agree
            send_key $cmd{next}, 2;
            send_key_until_needlematch 'addon-yast2-view-selected', 'alt-v', 10;
            send_key 'spc';                                                   # open view menu
            send_key 'alt-r', 1;
            send_key 'alt-r', 1;                                              # go to repositories
            send_key 'ret';                                                   # open repositories tab
            assert_screen "addon-yast2-repo-$addon";
            send_key 'alt-a';                                                 # accept
            assert_screen 'automatic-changes';
            send_key 'alt-o';                                                 # OK
            if (check_screen 'unsupported-packages', 5) {
                record_soft_failure 'unsupported packages';
                send_key 'alt-o';
            }
            if (check_screen 'addon-installation-pop-up', 100) {              # e.g. RT reboot to activate new kernel
                send_key 'alt-o';                                             # OK
            }
            assert_screen "addon-installation-report";
            send_key 'alt-f', 2;                                              # finish
            if (get_var('SCC_REGISTER')) {
                if (check_screen('scc-registration', 5)) {
                    fill_in_registration_data;
                }
                if ($addon ne 'sdk') {                                        # sdk doesn't ask for code
                    my $regcode = get_var("SCC_REGCODE_$uc_addon");
                    assert_screen "addon-reg-code";
                    send_key 'tab';                                           # jump to code field
                    type_string $regcode;
                    sleep 1;
                    save_screenshot;
                    send_key $cmd{next};
                }
                assert_screen 'addon-products',                     60;
                send_key "tab",                                     1;        # select addon-products-$addon
                send_key "pgup",                                    1;
                send_key_until_needlematch "addon-products-$addon", 'down';
            }
            else {
                send_key "alt-s", 1;                                          # skip SCC registration
                if (check_screen("scc-skip-reg-warning")) {
                    send_key "alt-y", 1;                                      # confirmed skip SCC registration
                }
                if (check_screen("scc-skip-base-system-reg-warning")) {
                    send_key "alt-y", 1;                                      # confirmed skip SCC registration
                }
            }
            if ((split(/,/, get_var('ADDONS')))[-1] ne $addon) {              # if $addon is not first from all ADDONS
                send_key 'alt-a', 2;                                          # add another add-on
            }
            else {
                send_key 'alt-o', 2;                                          # ok continue
            }
        }
    }
    else {
        send_key 'alt-n', 2;                                                  # done
    }
}

1;
# vim: set sw=4 et:
