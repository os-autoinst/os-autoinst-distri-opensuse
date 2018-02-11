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
use version_utils 'sle_version_at_least';
use qam 'advance_installer_window';
use registration qw(%SLE15_DEFAULT_MODULES rename_scc_addons);

sub handle_all_packages_medium {
    assert_screen 'addon-products-all_packages';
    send_key 'alt-s';

    # For SLE installation / upgrade with the all-packages media, user has
    # to select the required extensions / modules manually
    my $sle_prod = get_required_var('SLE_PRODUCT');
    my @addons = split(/,/, $SLE15_DEFAULT_MODULES{$sle_prod});

    # According to installation guide, select a sle product is mandatory
    # when install with the all-packages media, so add the base product
    # (sles/sled/etc) as a fake addon
    push @addons, $sle_prod if !grep(/^$sle_prod$/, @addons);

    # Select Desktop-Applications module if gnome is wanted
    push @addons, 'desktop' if check_var('DESKTOP', 'gnome') && !grep(/^desktop$/, @addons);

    # The SLEWE extension is required to install/upgrade SLED 15
    # Refer to https://bugzilla.suse.com/show_bug.cgi?id=1078958#c4
    push @addons, 'we' if check_var('SLE_PRODUCT', 'sled') && !grep(/^we$/, @addons);

    # The legacy module is required if upgrade from previous version (bsc#1066338)
    push @addons, 'legacy' if get_var('UPGRADE') && !grep(/^legacy$/, @addons);

    # In upgrade testing, the sle addons, including extensions and modules,
    # are defined with SCC_ADDONS, thus the addons could be patched on
    # the original system (the system-to-be-upgraded).
    # During system upgrade with all-packages media, the addons installed
    # on the original system should be mapped to new ones provided by media
    rename_scc_addons if sle_version_at_least('15');

    # Read addons from SCC_ADDONS and add them to list
    # Make sure every addon only appears once in the list,
    # there will be problem to enable the same addon twice
    for my $a (split(/,/, get_var('SCC_ADDONS', ''))) {
        push @addons, $a if !grep(/^$a$/, @addons);
    }

    # Record the addons to be enabled for debugging
    record_info 'Extension and Module Selection', join(' ', @addons);
    # Enable the extentions or modules
    foreach (@addons) {
        send_key 'home';
        send_key_until_needlematch "addon-products-all_packages-$_-highlighted", 'down';
        send_key 'spc';
    }
    send_key $cmd{next};
    # Confirm all required addons are properly added
    assert_screen 'addon-products', 60;
    foreach (@addons) {
        send_key 'home';
        send_key_until_needlematch "addon-products-$_", 'down';
    }
}

sub handle_addon {
    my ($addon) = @_;
    return handle_all_packages_medium if $addon eq 'all-packages';
    addon_license($addon);
    # might involve some network lookup of products, licenses, etc.
    assert_screen 'addon-products', 90;
    send_key 'tab';    # select addon-products-$addon
    wait_still_screen 10;
    if (check_var('VIDEOMODE', 'text')) {    # textmode need more tabs, depends on add-on count
        send_key_until_needlematch "addon-list-selected", 'tab';
    }
    send_key 'pgup';
    wait_still_screen 2;
    send_key_until_needlematch "addon-products-$addon", 'down';
    if (sle_version_at_least('15')) {
        send_key 'spc';
        send_key $cmd{next};
        wait_still_screen 2;
    }
}

sub run {
    my ($self) = @_;

    if (get_var('SKIP_INSTALLER_SCREEN', 0)) {
        advance_installer_window('inst-addon');
        set_var('SKIP_INSTALLER_SCREEN', 0);
    }
    $self->process_unsigned_files([qw(inst-addon addon-products)]);
    assert_screen [qw(inst-addon addon-products)];
    if (get_var("ADDONS")) {
        send_key match_has_tag('inst-addon') ? 'alt-k' : 'alt-a';
        # the ISO_X variables must match the ADDONS list
        my $sr_number = 0;
        for my $addon (split(/,/, get_var('ADDONS'))) {
            $sr_number++ unless (sle_version_at_least('15') && $sr_number == 1);
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
            send_key 'alt-u';                             # select URL field
            type_string get_var("ADDONURL_$uc_addon");    # repo URL
            send_key $cmd{next};
            wait_still_screen;                            # wait after key is pressed, e.g. 'addon-products' can apper shortly before initialization
            my @tags = ('addon-products', "addon-betawarning-$addon", "addon-license-$addon", 'import-untrusted-gpg-key');
            assert_screen(\@tags, 90);
            if (match_has_tag("addon-betawarning-$addon") or match_has_tag("addon-license-$addon")) {
                if (match_has_tag("addon-betawarning-$addon")) {
                    send_key "ret";
                    assert_screen [qw(addon-license-beta addon-products)];
                    record_soft_failure 'bsc#1057223: No license agreement shown when HA, HA-GEO, WE, RT extensions are added as addons'
                      unless match_has_tag("addon-license-beta");
                }
                if (match_has_tag("addon-license-beta") or match_has_tag("addon-license-$addon")) {
                    wait_still_screen 2;
                    send_key 'alt-a';                     # yes, agree
                    wait_still_screen 2;
                    send_key $cmd{next};
                    assert_screen 'addon-products', 90;
                }
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
