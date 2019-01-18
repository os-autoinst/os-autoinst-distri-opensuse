# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add add-on via DVD, network or DUD during installation
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils qw(addon_license handle_untrusted_gpg_key assert_screen_with_soft_timeout);
use version_utils 'is_sle';
use qam 'advance_installer_window';
use registration qw(%SLE15_DEFAULT_MODULES rename_scc_addons @SLE15_ADDONS_WITHOUT_LICENSE);
use LWP::Simple 'head';

sub handle_all_packages_medium {
    assert_screen 'addon-products-all_packages';
    send_key 'alt-s';

    # For SLE installation / upgrade with the all-packages media, user has
    # to select the required extensions / modules manually
    my $sle_prod = get_required_var('SLE_PRODUCT');
    my @addons   = split(/,/, $SLE15_DEFAULT_MODULES{$sle_prod});

    # According to installation guide, select a sle product is mandatory
    # when install with the all-packages media, so add the base product
    # (sles/sled/etc) as a fake addon
    push @addons, $sle_prod if !grep(/^$sle_prod$/, @addons);

    # Select Desktop-Applications module if gnome is wanted
    push @addons, 'desktop' if check_var('DESKTOP', 'gnome') && !grep(/^desktop$/, @addons);

    # The SLEWE extension is required to install/upgrade SLED 15
    # Refer to https://bugzilla.suse.com/show_bug.cgi?id=1078958#c4
    push @addons, 'we' if check_var('SLE_PRODUCT', 'sled') && !grep(/^we$/, @addons);

    # For SLES12SPx and SLES11SPx to SLES15 migration, need add the demand module at least for media migration manually
    # Refer to https://fate.suse.com/325293
    if (get_var('MEDIA_UPGRADE') && is_sle('<15', get_var('HDDVERSION')) && !check_var('SLE_PRODUCT', 'sled')) {
        my @demand_addon = qw(desktop serverapp script);
        push @demand_addon, 'sdk'    if !check_var('SLE_PRODUCT', 'sles4sap');
        push @demand_addon, 'legacy' if !check_var('SLE_PRODUCT', 'rt');
        for my $a (@demand_addon) {
            push @addons, $a if !grep(/^$a$/, @addons);
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
    for my $a (split(/,/, get_var('SCC_ADDONS', ''))) {
        push @addons, $a if !grep(/^$a$/, @addons);
    }

    # Record the addons to be enabled for debugging
    record_info 'Extension and Module Selection', join(' ', @addons);
    # Enable the extentions or modules
    # Also record the addons which require license agreement
    my @addons_with_license = qw(ha we);
    my @addons_license_tags = ();
    for my $a (@addons) {
        push @addons_license_tags, "addon-license-$a" if grep(/^$a$/, @addons_with_license);
        send_key 'home';
        send_key_until_needlematch "addon-products-all_packages-$a-highlighted", 'down';
        send_key 'spc';
    }
    send_key $cmd{next};
    # Check the addon license agreement
    # To avoid repetition to much, set a counter to match:
    # addon licenses, sles(d) license (as workaround), and addon-products
    my $counter           = 2 + (scalar @addons_license_tags);
    my $addon_license_num = 0;
    while ($counter--) {
        assert_screen([qw(addon-products-nonempty sle-product-license-agreement)], 60);
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
    foreach (@addons) {
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
    send_key_until_needlematch "addon-products-$addon", 'down';
    # modules like SES or RT that are not part of Packages ISO don't have this step
    if (is_sle('15+') && $addon !~ /^ses$|^rt$/) {
        send_key 'spc';
        wait_screen_change { send_key $cmd{next} };
        assert_screen 'addon-product-installation';
    }
}

sub test_addonurl {
    my $testvalue = get_var('ADDONURL');
    my @missing_modules;
    my @test_modules = split(/,/, get_var('WORKAROUND_MODULES'));

    foreach (@test_modules) {
        push @missing_modules, $_ unless ($testvalue =~ $_);
        die('URL ADDONURL_' . uc $_ . ' could not be accessed') unless head(get_var('ADDONURL_' . uc $_));
    }

    if (@missing_modules) {
        my $str_missed_mod = join(',', @missing_modules);
        die "Missing modules in ADDONURL which are set in WORKAROUND_MODULES: $str_missed_mod";
    }
}

sub run {
    my ($self) = @_;

    if (get_var('SKIP_INSTALLER_SCREEN', 0)) {
        advance_installer_window('inst-addon');
        set_var('SKIP_INSTALLER_SCREEN', 0);
    }
    $self->process_unsigned_files([qw(inst-addon addon-products)]);
    assert_screen_with_soft_timeout([qw(inst-addon addon-products)], timeout => 60, soft_timeout => 30, bugref => 'bsc#1123963');
    if (get_var("ADDONS")) {
        send_key match_has_tag('inst-addon') ? 'alt-k' : 'alt-a';
        # the ISO_X variables must match the ADDONS list
        my $sr_number = 0;
        for my $addon (split(/,/, get_var('ADDONS'))) {
            $sr_number++ unless (is_sle('15+') && $sr_number == 1);
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
    test_addonurl
      if is_sle('>=15')
      and !check_var('SCC_REGISTER', 'installation')
      and (get_var('ALL_MODULES') || get_var('WORKAROUND_MODULES'));

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
            send_key 'alt-u';                                      # select URL field
            type_string get_required_var("ADDONURL_$uc_addon");    # repo URL
            send_key $cmd{next};
            wait_still_screen;                                     # wait after key is pressed, e.g. 'addon-products' can apper shortly before initialization
            my @tags = ('addon-products', "addon-betawarning-$addon", "addon-license-$addon", 'import-untrusted-gpg-key');
            assert_screen(\@tags, 90);
            if (match_has_tag("addon-betawarning-$addon") or match_has_tag("addon-license-$addon")) {
                if (match_has_tag("addon-betawarning-$addon")) {
                    send_key "ret";
                    assert_screen "addon-license-beta";
                }
                wait_still_screen 2;
                send_key 'alt-a';                                  # yes, agree
                wait_still_screen 2;
                send_key $cmd{next};
                assert_screen 'addon-products', 90;
            }
            elsif (match_has_tag('import-untrusted-gpg-key')) {
                handle_untrusted_gpg_key;
            }
            send_key "tab";                                        # select addon-products-$addon
            wait_still_screen 10;                                  # wait until repo is added and list is initialized
            if (check_var('VIDEOMODE', 'text')) {                  # textmode need more tabs, depends on add-on count
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
