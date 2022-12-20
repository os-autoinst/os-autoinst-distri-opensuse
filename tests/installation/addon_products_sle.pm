# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add add-on via DVD, network or DUD during installation
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use Utils::Backends;
use utils qw(addon_license handle_untrusted_gpg_key assert_screen_with_soft_timeout);
use version_utils 'is_sle';
use qam 'advance_installer_window';
use registration qw(%SLE15_DEFAULT_MODULES rename_scc_addons @SLE15_ADDONS_WITHOUT_LICENSE skip_package_hub_if_necessary);
use LWP::Simple 'head';

sub handle_all_packages_medium {
    assert_screen 'addon-products-all_packages';
    send_key 'alt-s';

    # For SLE installation / upgrade with the all-packages media, user has
    # to select the required extensions / modules manually
    my $sle_prod = get_required_var('SLE_PRODUCT');
    my @addons = split(/,/, $SLE15_DEFAULT_MODULES{$sle_prod});

    # According to installation guide, select a sle product is mandatory
    # (from sle15-SP2 this is not true)
    # when install with the all-packages media, so add the base product
    # (sles/sled/etc) as a fake addon.
    unless (is_sle('15-SP2+')) {
        push @addons, $sle_prod if !grep(/^$sle_prod$/, @addons);
    }
    # Select Desktop-Applications module if gnome is wanted
    push @addons, 'desktop' if check_var('DESKTOP', 'gnome') && !grep(/^desktop$/, @addons);

    # The SLEWE extension is required to install/upgrade SLED 15
    # Refer to https://bugzilla.suse.com/show_bug.cgi?id=1078958#c4
    push @addons, 'we' if check_var('SLE_PRODUCT', 'sled') && !grep(/^we$/, @addons);

    # For SLES12SPx and SLES11SPx to SLES15 migration, need add the demand module at least for media migration manually
    # Refer to https://fate.suse.com/325293
    if (get_var('MEDIA_UPGRADE') && is_sle('<15', get_var('HDDVERSION')) && !check_var('SLE_PRODUCT', 'sled')) {
        my @demand_addon = qw(desktop serverapp script);
        push @demand_addon, 'sdk' if !check_var('SLE_PRODUCT', 'sles4sap');
        push @demand_addon, 'legacy' if !check_var('SLE_PRODUCT', 'rt');
        for my $i (@demand_addon) {
            push @addons, $i if !grep(/^$i$/, @addons);
        }
    }
    # In upgrade testing, the sle addons, including extensions and modules,
    # are defined with SCC_ADDONS, thus the addons could be patched on
    # the original system (the system-to-be-upgraded).
    # During system upgrade with all-packages media, the addons installed
    # on the original system should be mapped to new ones provided by media
    rename_scc_addons if is_sle('15+');

    # Read addons from SCC_ADDONS and add them to list
    # Make sure every addon only appears once in the list,
    # there will be problem to enable the same addon twice
    for my $i (split(/,/, get_var('SCC_ADDONS', ''))) {
        push @addons, $i if !grep(/^$i$/, @addons);
    }

    # Record the addons to be enabled for debugging
    record_info 'Extension and Module Selection', join(' ', @addons);
    # Enable the extensions or modules
    # Also record the addons which require license agreement
    my @addons_with_license = qw(ha we);
    my @addons_license_tags = ();
    send_key_until_needlematch 'addon-base-activated', 'tab' if (check_var('VIDEOMODE', 'text'));
    for my $i (@addons) {
        next if (skip_package_hub_if_necessary($i));
        push @addons_license_tags, "addon-license-$i" if grep(/^$i$/, @addons_with_license);
        send_key 'home';
        send_key_until_needlematch ["addon-products-all_packages-$i-highlighted", "addon-products-all_packages-$i-selected"], "down", 31;
        if (match_has_tag("addon-products-all_packages-$i-highlighted")) {
            send_key 'spc';
        } else {
            record_info("Module preselected", "Module $i is already selected");
        }
    }
    send_key $cmd{next};
    # Check the addon license agreement
    # To avoid repetition to much, set a counter to match:
    # addon licenses, sles(d) license (as workaround), and addon-products
    my $counter = 2 + (scalar @addons_license_tags);
    my $addon_license_num = 0;
    while ($counter--) {
        assert_screen([qw(addon-products-nonempty sle-product-license-agreement)], 240);
        last if (match_has_tag 'addon-products-nonempty');
        if (match_has_tag 'sle-product-license-agreement') {
            if (@addons_license_tags && check_screen(\@addons_license_tags, 30)) {
                $addon_license_num++;
            }
            wait_screen_change { send_key 'alt-a' };
            wait_screen_change { send_key 'alt-n' };
        }
    }
    record_info "Error", "License agreement not shown for some addons", result => 'fail'
      if @addons_license_tags && ($addon_license_num != scalar @addons_license_tags);
    assert_screen "addon-products-nonempty";
    # Confirm all required addons are properly added
    send_key 'tab' if (check_var('VIDEOMODE', 'text'));
    foreach (@addons) {
        next if (skip_package_hub_if_necessary($_));
        send_key 'home';
        send_key_until_needlematch "addon-products-$_", 'down';
    }
}

sub handle_addon {
    my ($addon) = @_;
    return handle_all_packages_medium if $addon eq 'all-packages';
    # SES6 on SLE15 in development has untrusted key warning
    addon_license($addon) unless is_sle('15+') && $addon !~ /^ses$|^rt$/;
    # might involve some network lookup of products, licenses, etc.
    assert_screen ['addon-products', 'import-untrusted-gpg-key'], 90;
    if (match_has_tag('import-untrusted-gpg-key')) {
        handle_untrusted_gpg_key;
    }
    send_key 'tab';    # select addon-products-$addon
    wait_still_screen 10;
    if (check_var('VIDEOMODE', 'text')) {    # textmode need more tabs, depends on add-on count
        send_key_until_needlematch "addon-list-selected", 'tab';
    }
    send_key 'pgup';
    wait_still_screen 2;
    send_key_until_needlematch "addon-products-$addon", 'down', 31;
    # modules like SES or RT that are not part of Packages ISO don't have this step
    send_key 'spc' if (is_sle('15+') && $addon !~ /^ses$|^rt$/);
    # Return to top of the list
    for (1 .. 15) { send_key 'pgup' }
}

sub test_addonurl {
    my @test_modules = split(/,/, get_var('ADDONURL'));

    foreach (@test_modules) {
        die('URL ADDONURL_' . uc $_ . ' could not be accessed') unless head(get_var('ADDONURL_' . uc $_));
    }
}

sub run {
    my ($self) = @_;

    if (get_var('SKIP_INSTALLER_SCREEN', 0)) {
        advance_installer_window('inst-addon');
        set_var('SKIP_INSTALLER_SCREEN', 0);
    }
    # Wait for the addon products screen if needed
    unless (is_sle('15-SP2+') && get_var('MEDIA_UPGRADE')) {
        if ($self->process_unsigned_files([qw(inst-addon addon-products)])) {
            assert_screen_with_soft_timeout(
                [qw(inst-addon addon-products)],
                timeout => is_pvm_hmc ? 600 : 120,
                soft_timeout => 60,
                bugref => 'bsc#1166504');
        }
    }
    if (get_var("ADDONS")) {
        send_key match_has_tag('inst-addon') ? 'alt-k' : 'alt-a';
        # the ISO_X variables must match the ADDONS list
        my $sr_number = 0;
        my $last_addon;
        for my $addon (split(/,/, get_var('ADDONS'))) {
            $sr_number++ unless (is_sle('15+') && $sr_number == 1);
            # in full_installer the dialog to choose the installation media
            # does not appear, thus we have to skip it
            unless ((check_var('FLAVOR', 'Full')) || check_var('FLAVOR', 'Full-QR') || ((is_sle('15-SP2+') && get_var('MEDIA_UPGRADE')))) {
                assert_screen 'addon-menu-active';
                wait_screen_change { send_key 'alt-d' };    # DVD
                send_key $cmd{next};
                assert_screen 'dvd-selector';
                send_key_until_needlematch 'addon-dvd-list', 'tab', 6;    # jump into addon list
                send_key_until_needlematch "addon-dvd-sr$sr_number", 'down', 11;    # select addon in list
                send_key 'alt-o';    # continue
            }
            handle_addon($addon);
            # add another add-on if $addon is not first from all ADDONS and not in SLE 15+
            send_key 'alt-a' if (is_sle('<15') && ((split(/,/, get_var('ADDONS')))[-1] ne $addon));
            $last_addon = $addon;
        }
        if (is_sle('15+') && $last_addon !~ /^ses$|^rt$/) {
            if (get_var('ADDONS') !~ /all-packages/) {
                # handle_all_packages_medium() leaves the installer one step further
                # so click on Next if it was not called
                wait_screen_change { send_key $cmd{next} };
            }
            assert_screen 'addon-product-installation';
        }
    }
    test_addonurl if is_sle('>=15') && get_var('ADDONURL');
    if (get_var("ADDONURL")) {
        if (match_has_tag('inst-addon')) {
            send_key 'alt-k';    # install with addons
        }
        else {
            send_key 'alt-a';
        }
        for my $addon (split(/,/, get_var('ADDONURL'))) {
            assert_screen 'addon-menu-active';
            my $uc_addon = uc $addon;    # variable name is upper case
            send_key 'alt-u';    # specify url
            send_key $cmd{next};
            assert_screen 'addonurl-entry';
            send_key 'alt-u';    # select URL field
            type_string get_required_var("ADDONURL_$uc_addon");    # repo URL
            send_key $cmd{next};
            wait_still_screen;    # wait after key is pressed, e.g. 'addon-products' can apper shortly before initialization
            my @tags = ('addon-products', "addon-betawarning-$addon", "addon-license-$addon", 'import-untrusted-gpg-key');
            assert_screen(\@tags, 90);
            if (match_has_tag("addon-betawarning-$addon") or match_has_tag("addon-license-$addon")) {
                if (match_has_tag("addon-betawarning-$addon")) {
                    send_key "ret";
                    assert_screen "addon-license-beta";
                }
                wait_still_screen 2;
                send_key 'alt-a';    # yes, agree
                wait_still_screen 2;
                send_key $cmd{next};
                assert_screen 'addon-products', 90;
            }
            elsif (match_has_tag('import-untrusted-gpg-key')) {
                handle_untrusted_gpg_key;
            }
            send_key "tab";    # select addon-products-$addon
            wait_still_screen 10;    # wait until repo is added and list is initialized
            if (check_var('VIDEOMODE', 'text')) {    # textmode need more tabs, depends on add-on count
                send_key_until_needlematch "addon-list-selected", 'tab';
            }
            send_key "pgup";
            wait_still_screen 2;
            send_key_until_needlematch "addon-products-$addon", 'down';
            if ((split(/,/, get_var('ADDONURL')))[-1] ne $addon) {    # if $addon is not first from all ADDONS
                send_key 'alt-a';    # add another add-on
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
    send_key $cmd{next} if check_screen 'addon_product_installation';
}

1;
