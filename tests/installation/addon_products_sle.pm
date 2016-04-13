# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    assert_screen [qw/inst-addon addon-products/];
    if (get_var("ADDONS")) {
        if (match_has_tag('inst-addon')) {
            send_key 'alt-k';    # install with addons
        }
        else {
            send_key 'alt-a';
        }
        # the ISO_X variables must match the ADDONS list
        my $sr_number = 0;
        for my $addon (split(/,/, get_var('ADDONS'))) {
            $sr_number++;
            assert_screen 'addon-menu-active';
            send_key 'alt-d', 3;    # DVD
            send_key 'alt-n';
            assert_screen 'dvd-selector';
            send_key_until_needlematch 'addon-dvd-list',         'tab',  10;    # jump into addon list
            send_key_until_needlematch "addon-dvd-sr$sr_number", 'down', 10;    # select addon in list
            send_key 'alt-o';                                                   # continue
            if (check_screen('import-untrusted-gpg-key', 10)) {                 # workaround untrusted key pop-up, record soft fail and trust it
                record_soft_failure 'untrusted gpg key';
                send_key 'alt-t';
            }
            my $uc_addon = uc $addon;                                           # variable name is upper case
            if (get_var("BETA_$uc_addon")) {
                assert_screen "addon-betawarning-$addon";
                send_key "ret";
                assert_screen "addon-license-beta";
            }
            else {
                assert_screen "addon-license-$addon";
            }
            sleep 2;
            send_key 'alt-a';                                                   # yes, agree
            sleep 2;
            send_key 'alt-n';                                                   # next
            assert_screen 'addon-products';
            send_key "tab", 1;                                                  # select addon-products-$addon
            if (check_var('VIDEOMODE', 'text')) {                               # textmode need more tabs, depends on add-on count
                send_key_until_needlematch "addon-list-selected", 'tab';
            }
            send_key "pgup",                                    1;
            send_key_until_needlematch "addon-products-$addon", 'down';
            if ((split(/,/, get_var('ADDONS')))[-1] ne $addon) {                # if $addon is not first from all ADDONS
                send_key 'alt-a';                                               # add another add-on
            }
            else {
                send_key 'alt-n';                                               # next
            }
        }
    }
    elsif (get_var("ADDONURL")) {
        if (match_has_tag('inst-addon')) {
            send_key 'alt-k';                                                   # install with addons
        }
        else {
            send_key 'alt-a';
        }
        for my $addon (split(/,/, get_var('ADDONURL'))) {
            assert_screen 'addon-menu-active';
            my $uc_addon = uc $addon;                                           # varibale name is upper case
            send_key 'alt-u';                                                   # specify url
            send_key 'alt-n';
            assert_screen 'addonurl-entry';
            send_key 'alt-u';                                                   # select URL field
            type_string get_var("ADDONURL_$uc_addon");                          # repo URL
            send_key 'alt-n';
            assert_screen 'addon-products', 90;
            send_key "tab";                                                     # select addon-products-$addon
            if (check_var('VIDEOMODE', 'text')) {                               # textmode need more tabs, depends on add-on count
                send_key_until_needlematch "addon-list-selected", 'tab';
            }
            send_key "pgup",                                    1;
            send_key_until_needlematch "addon-products-$addon", 'down';
            if ((split(/,/, get_var('ADDONURL')))[-1] ne $addon) {              # if $addon is not first from all ADDONS
                send_key 'alt-a';                                               # add another add-on
            }
            else {
                send_key 'alt-n';                                               # next
            }
        }
    }
    else {
        send_key 'alt-n', 3;                                                    # done
    }
}

1;
# vim: set sw=4 et:
