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
use utils qw(addon_license sle_version_at_least);
use qam 'advance_installer_window';
use registration '%SLE15_DEFAULT_MODULES';

sub handle_all_packages_medium {
    assert_screen 'addon-products-all_packages';
    send_key 'alt-s';
    # We could reuse SCC_MODULES or another list. For now just hardcode what
    # corresponds to the selected SLE15 product because the "all packages"
    # addon medium and feature of installer is only available for SLE >= 15
    # anyway
    foreach (split(/,/, $SLE15_DEFAULT_MODULES{get_required_var('SLE_PRODUCT')})) {
        send_key 'home';
        send_key_until_needlematch "addon-products-all_packages-$_-highlighted", 'down';
        send_key 'spc';
    }
    send_key $cmd{next};
}

sub handle_addon {
    my ($addon) = @_;
    return handle_all_packages_medium if $addon eq 'all-packages';
    addon_license($addon);
    # might involve some network lookup of products, licenses, etc.
    assert_screen 'addon-products', 90;
    send_key "tab";    # select addon-products-$addon
    wait_still_screen 10;
    if (check_var('VIDEOMODE', 'text')) {    # textmode need more tabs, depends on add-on count
        send_key_until_needlematch "addon-list-selected", 'tab';
    }
    send_key "pgup";
    wait_still_screen 2;
    send_key_until_needlematch "addon-products-$addon", 'down';
}

sub run {
    my ($self) = @_;

    if (get_var('SKIP_INSTALLER_SCREEN', 0)) {
        advance_installer_window('inst-addon');
        set_var('SKIP_INSTALLER_SCREEN', 0);
    }
    $self->process_unsigned_files([qw(inst-addon addon-products)]);
    assert_screen [qw(inst-addon addon-products)];
    # enable dialog
    # for later: if ((get_var('ADDONS') || get_var('ADDONURL')) && !sle_version_at_least('15')) {
    # for now, only enable this for STAGING:Y
    if (check_var('FLAVOR', 'Installer-DVD-Staging:Y')) {
        send_key match_has_tag('inst-addon') ? 'alt-k' : 'alt-a';
    }
    if (get_var("ADDONS")) {
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
            handle_addon($addon);
            if ((split(/,/, get_var('ADDONS')))[-1] ne $addon) {                # if $addon is not first from all ADDONS
                send_key 'alt-a';                                               # add another add-on
            }
        }
    }
    if (get_var("ADDONURL")) {
        for my $addon (split(/,/, get_var('ADDONURL'))) {
            assert_screen 'addon-menu-active';
            my $uc_addon = uc $addon;                                           # varibale name is upper case
            send_key 'alt-u';                                                   # specify url
            send_key $cmd{next};
            assert_screen 'addonurl-entry';
            send_key 'alt-u';                             # select URL field
            type_string get_var("ADDONURL_$uc_addon");    # repo URL
            send_key $cmd{next};
            wait_still_screen;                            # wait after key is pressed, e.g. 'addon-products' can apper shortly before initialization
            my @tags = ('addon-products', "addon-betawarning-$addon", "addon-license-$addon", 'import-untrusted-gpg-key');
            assert_screen(\@tags, 90);
            if (match_has_tag("addon-betawarning-$addon") or match_has_tag("addon-license-$addon")) {
                if (match_has_tag("addon-betawarning-$addon")) {
                    send_key "ret";
                    assert_screen "addon-license-beta";
                }
                wait_still_screen 2;
                send_key 'alt-a';                         # yes, agree
                wait_still_screen 2;
                send_key $cmd{next};
                assert_screen 'addon-products', 90;
            }
            elsif (match_has_tag('import-untrusted-gpg-key')) {
                send_key 'alt-t';
            }
            send_key "tab";                               # select addon-products-$addon
            wait_still_screen 10;                         # wait until repo is added and list is initialized
            if (check_var('VIDEOMODE', 'text')) {         # textmode need more tabs, depends on add-on count
                send_key_until_needlematch "addon-list-selected", 'tab';
            }
            send_key "pgup";
            wait_still_screen 2;
            send_key_until_needlematch "addon-products-$addon", 'down';
            if ((split(/,/, get_var('ADDONURL')))[-1] ne $addon) {    # if $addon is not first from all ADDONS
                send_key 'alt-a';                                     # add another add-on
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
