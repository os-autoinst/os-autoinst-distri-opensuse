# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add add-on via DVD, network or DUD during installation
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use base "y2logsstep";
use testapi;
use utils 'addon_license';

sub run() {
    if (check_var('VERSION', '15')) {    # SLE 15 has unsigned file errors, workaround them - rbrown 04/07/2017
        while (check_screen('sle-15-unsigned-file')) {
            record_soft_failure 'bsc#1047304';
            send_key 'alt-y';
        }
    }
    assert_screen [qw(inst-addon addon-products)];
    if (get_var("ADDONS")) {
        if (match_has_tag('inst-addon')) {
            send_key 'alt-k';            # install with addons
        }
        else {
            send_key 'alt-a';
        }
        # the ISO_X variables must match the ADDONS list
        my $sr_number = 0;
        for my $addon (split(/,/, get_var('ADDONS'))) {
            $sr_number++;
            assert_screen 'addon-menu-active';
            wait_screen_change { send_key 'alt-d' };    # DVD
            send_key $cmd{next};
            assert_screen 'dvd-selector';
            send_key_until_needlematch 'addon-dvd-list',         'tab',  5;     # jump into addon list
            send_key_until_needlematch "addon-dvd-sr$sr_number", 'down', 10;    # select addon in list
            send_key 'alt-o';                                                   # continue
            addon_license($addon);
            # might involve some network lookup of products, licenses, etc.
            assert_screen 'addon-products', 90;
            send_key "tab";                                                     # select addon-products-$addon
            wait_still_screen 2;
            if (check_var('VIDEOMODE', 'text')) {                               # textmode need more tabs, depends on add-on count
                send_key_until_needlematch "addon-list-selected", 'tab';
            }
            send_key "pgup";
            wait_still_screen 2;
            send_key_until_needlematch "addon-products-$addon", 'down';
            if ((split(/,/, get_var('ADDONS')))[-1] ne $addon) {                # if $addon is not first from all ADDONS
                send_key 'alt-a';                                               # add another add-on
            }
        }
    }
    if (get_var("ADDONURL")) {
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
            send_key $cmd{next};
            assert_screen 'addonurl-entry';
            send_key 'alt-u';                                                   # select URL field
            type_string get_var("ADDONURL_$uc_addon");                          # repo URL
            send_key $cmd{next};
            my @tags = ('addon-products', "addon-betawarning-$addon", "addon-license-$addon", 'import-untrusted-gpg-key');
            assert_screen(\@tags, 90);
            if (match_has_tag("addon-betawarning-$addon") or match_has_tag("addon-license-$addon")) {
                if (match_has_tag("addon-betawarning-$addon")) {
                    send_key "ret";
                    assert_screen "addon-license-beta";
                }
                wait_still_screen 2;
                send_key 'alt-a';                                               # yes, agree
                wait_still_screen 2;
                send_key $cmd{next};
                assert_screen 'addon-products', 90;
            }
            elsif (match_has_tag('import-untrusted-gpg-key')) {
                send_key 'alt-t';
            }
            send_key "tab";                                                     # select addon-products-$addon
            if (check_var('VIDEOMODE', 'text')) {                               # textmode need more tabs, depends on add-on count
                send_key_until_needlematch "addon-list-selected", 'tab';
            }
            send_key "pgup";
            wait_still_screen 2;
            send_key_until_needlematch "addon-products-$addon", 'down';
            if ((split(/,/, get_var('ADDONURL')))[-1] ne $addon) {              # if $addon is not first from all ADDONS
                send_key 'alt-a';                                               # add another add-on
            }
        }
    }
    if (get_var('DUD_ADDONS')) {
        for my $addon (split(/,/, get_var('DUD_ADDONS'))) {
            send_key "pgup";
            wait_still_screen 2;
            send_key_until_needlematch "addon-products-$addon", 'down';
        }
    }
    send_key $cmd{next};
    wait_still_screen 5;
}

1;
# vim: set sw=4 et:
