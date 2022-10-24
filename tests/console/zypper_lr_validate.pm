# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Validate SLE zypper repositories
# - List download repositories and outputs to serial device
# - Calls validate_repos_sle (checks system variables, SLE channels table,
# products, install media, architectures and determine if the correct
# repositores are added)
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use Utils::Architectures;
use utils;
use version_utils 'is_sle';

sub validatelr {
    my ($args) = @_;

    my $alias = $args->{alias} || "";
    my $product = $args->{product};
    my $product_channel = $args->{product_channel} || "";
    my $version = $args->{version};
    my $major_version = substr($args->{version}, 0, 2);
    if (get_var('ZDUP')) {
        $version = "";
    }
    if (get_var('FLAVOR') =~ m{SAP}) {
        $version .= "-SAP";
    }
    # Live patching and other modules are not per-service pack channel model,
    # so use major version on sle12 to validate their repos
    if ($product eq 'SLE-ASMM') {
        $product = 'SLE-Module-Adv-Systems-Management';
        $version = $major_version if $major_version eq '12';
    }
    if ($product eq 'SLE-CONTM') {
        $product = 'SLE-Module-Containers';
        $version = $major_version if $major_version eq '12';
    }
    if ($product eq 'SLE-TCM') {
        $product = 'SLE-Module-Toolchain';
        $version = $major_version if $major_version eq '12';
    }
    if ($product eq 'SLE-WSM') {
        $product = 'SLE-Module-Web-Scripting';
        $version = $major_version if $major_version eq '12';
    }
    # LTSS version is included in its product name
    # leave it as empty to match the regex
    if ($product =~ /LTSS/) {
        $version = '' if $major_version eq '12';
    }
    diag "validatelr alias:$alias product:$product cha:$product_channel version:$version";

    # Repo is checked for enabled/disabled state. If the information about the
    # expected state is not delivered to validatelr(), we use some heuristics to
    # determine the expected state: If the installation medium is a physical
    # medium and the system is registered to SCC the repo should be disabled
    # if the system is SLE 12 SP2 and later; enabled otherwise, see PR#11460 and
    # FATE#320494.
    my $scc_install_sle12sp2 = check_var('SCC_REGISTER', 'installation') and is_sle('12-SP2+');
    my $enabled_repo;
    if ($args->{enabled_repo}) {
        $enabled_repo = $args->{enabled_repo};
    }
    # bsc#1012258, bsc#793709: USB repo is disabled as the USB stick will be
    # very likely removed from the system.
    elsif ($args->{uri} =~ m{(cd|dvd|hd):///.*usb-}) {
        $enabled_repo = 'No';
    }
    elsif ($args->{uri} =~ m{(cd|dvd|hd):///.*usbstick-}) {
        record_soft_failure 'boo#1019634 repo on USB medium is not disabled for "hd:///…scsi…usbstick"';
        $enabled_repo = 'Yes';
    }
    elsif ($args->{uri} =~ m{(cd|dvd|hd):///} and $scc_install_sle12sp2) {
        $enabled_repo = 'No';
    }
    else {
        $enabled_repo = 'Yes';
    }
    my $uri = $args->{uri};

    my $cmd;
    if ($product =~ /IBM-DLPAR-(Adv-Toolchain|SDK|utils)/) {
        $cmd
          = "zypper lr --uri | awk -F \'|\' -v OFS=\' \' \'{ print \$3,\$4,\$NF }\' | tr -s \' \' | grep --color \"$product\[\[:space:\]\[:punct:\]\[:space:\]\]*$enabled_repo $uri\"";
    }
    elsif (is_sle) {
        if (is_sle('15+')) {
            my $distri = uc(get_var('DISTRI'));
            $cmd
              = "zypper lr --uri | awk -F \'|\' -v OFS=\' \' \'{ print \$2,\$3,\$4,\$NF }\' | tr -s \' \' | grep --color \"$distri\[\[:alnum:\]\[:punct:\]\]*-*$version-$product_channel $distri\[\[:alnum:\]\[:punct:\]\[:space:\]\]*-*$version-$product_channel $enabled_repo $uri\"";
        }
        else {
            # SLES12 does not have 'SLES12-Source-Pool' SCC channel
            unless (($version eq "12") and ($product_channel eq "Source-Pool")) {
                $cmd
                  = "zypper lr --uri | awk -F \'|\' -v OFS=\' \' \'{ print \$2,\$3,\$4,\$NF }\' | tr -s \' \' | grep --color \"$product$version\[\[:alnum:\]\[:punct:\]\]*-*$product_channel $product$version\[\[:alnum:\]\[:punct:\]\[:space:\]\]*-*$product_channel $enabled_repo $uri\"";
            }
        }
    }
    script_output($cmd) if defined $cmd;
}

sub validate_repos_sle {
    my ($version) = @_;

    # On SLE we follow "SLE Channels Checking Table"
    # (https://wiki.microfocus.net/index.php?title=SLE12_SP2_Channels_Checking_Table)
    my (%h_addons, %h_addonurl, %h_scc_addons);
    my @addons_keys = split(/,/, get_var('ADDONS', ''));
    my @addonurl_keys = split(/,/, get_var('ADDONURL', ''));
    my $scc_addon_str = '';
    for my $scc_addon (split(/,/, get_var('SCC_ADDONS', ''))) {
        # no empty $scc_addon when SCC_ADDONS starts with ,
        next unless length $scc_addon;
        # The form of LTSS repos is different with other addons
        # For example: SLES12-LTSS-Updates
        if ($scc_addon eq 'ltss') {
            $scc_addon_str .= "SLES$version-" . uc($scc_addon) . ',';
            next;
        }
        $scc_addon =~ s/geo/ha-geo/ if ($scc_addon eq 'geo');
        $scc_addon_str .= "SLE-" . uc($scc_addon) . ',';
    }
    my @scc_addons_keys = split(/,/, $scc_addon_str);
    @h_addons{@addons_keys} = ();
    @h_addonurl{@addonurl_keys} = ();
    @h_scc_addons{@scc_addons_keys} = ();

    my $base_product;
    if (is_sle) {
        $base_product = (get_var('FLAVOR') =~ m{Desktop-DVD}) ? 'SLED' : 'SLES';
    }

    # On Xen PV there are no CDs nor DVDs being emulated, "raw" HDD is used instead
    my $cd = (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) ? 'hd' : 'cd';
    my $dvd = (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) ? 'hd' : 'dvd';

    # On system with ONLINE_MIGRATION/ZDUP variable set, we don't have SLE media
    # repository of VERSION N but N-1 (i.e. on SLES12-SP2 we have SLES12-SP1
    # repository. For the sake of sanity, the base product repo is not being
    # verified in such a scenario.
    if (!(get_var('ONLINE_MIGRATION') || get_var('ZDUP'))) {
        # This is where we verify base product repos for SLES, SLED, and HA
        my $uri = is_s390x ? "ftp://" : "$cd:///";
        if (check_var('FLAVOR', 'Server-DVD')) {
            if (is_ipmi || check_var("BACKEND", "generalhw")) {
                $uri = "http[s]*://.*suse";
            }
            elsif (get_var('USBBOOT') && is_sle('12-SP3+')) {
                $uri = "hd:///.*usb-";
            }
            elsif (get_var('USBBOOT') && is_sle('12-SP2+')) {
                $uri = "hd:///.*usbstick";
            }
            validatelr({product => "SLES", uri => $uri, version => $version});
        }
        elsif (check_var('FLAVOR', 'SAP-DVD')) {
            validatelr({product => "SLE-", uri => $uri, version => $version});
        }
        elsif (check_var('FLAVOR', 'Server-DVD-HA')) {
            validatelr({product => "SLES", uri => $uri, version => $version});
            validatelr({product => 'SLE-*HA', uri => get_var('ADDONURL_HA') || "$dvd:///", version => $version});
            if (exists $h_addonurl{geo} || exists $h_addons{geo}) {
                validatelr({product => 'SLE-*HAGEO', uri => get_var('ADDONURL_GEO') || "$dvd:///", version => $version});
            }
            delete @h_addonurl{qw(ha geo)};
            delete @h_addons{qw(ha geo)};
        }
        elsif (check_var('FLAVOR', 'Desktop-DVD')) {
            # Note: verification of AMD (SLED12) and NVIDIA (SLED12, SP1, and SP2) repos is missing
            validatelr({product => "SLED", uri => $uri, version => $version});
        }
    }

    # URI Addons
    for my $addonurl_prod (keys %h_addonurl) {
        my $addonurl_tmp;
        if ($addonurl_prod eq "sdk") {
            $addonurl_tmp = $addonurl_prod;
        }
        else {
            $addonurl_tmp = "sle" . $addonurl_prod;
        }
        validatelr({product => uc $addonurl_tmp, uri => get_var("ADDONURL_" . uc $addonurl_prod), version => $version});
    }

    # DVD Addons; FATE#320494 (PR#11460): disable installation source after installation if we register system
    for my $addon (keys %h_addons) {
        if ($addon ne "sdk") {
            $addon = "sle" . $addon;
        }
        validatelr(
            {
                product => uc $addon,
                enabled_repo => get_var('SCC_REGCODE_' . uc $addon) ? "No" : "Yes",
                uri => "$dvd:///",
                version => $version
            });
    }

    # Verify SLES, SLED, Addons and their online SCC sources, if SCC_REGISTER is enabled
    if (check_var('SCC_REGISTER', 'installation') && !get_var('ZDUP')) {
        my ($uri, $nvidia_uri, $we);

        # Set uri and nvidia uri for smt registration and others (scc, proxyscc)
        # For smt url variable, we have to use https to import smt server's certification
        # After registration, the uri of smt could be http
        if (get_var('SMT_URL')) {
            ($uri = get_var('SMT_URL')) =~ s/https:\/\///;
            $uri = "http[s]*://" . $uri;
            $nvidia_uri = $uri;
        }
        else {
            $uri = "http[s]*://.*suse";
            $nvidia_uri = "http[s]*://.*nvidia";
        }

        for my $scc_product ($base_product, keys %h_scc_addons) {
            # Skip PackageHub as being not part of modules to validate
            next if $scc_product eq 'SLE-PHUB';
            # there will be no nvidia repo when WE add-on was removed with MIGRATION_REMOVE_ADDONS
            my $addon_removed = uc get_var('MIGRATION_REMOVE_ADDONS', 'none');
            $we = 1 if ($scc_product eq 'SLE-WE' && $scc_product !~ /$addon_removed/);
            for my $product_channel ("Pool", "Updates", "Debuginfo-Pool", "Debuginfo-Updates", "Source-Pool") {
                # Toolchain module doesn't have Source-Pool channel
                next if (($scc_product eq 'SLE-TCM') && ($product_channel eq 'Source-Pool'));
                # LTSS doesn't have Pool, Debuginfo-Pool and Source-Pool channels
                next if (($scc_product =~ /LTSS/) && ($product_channel =~ /(|Debuginfo-|Source-)Pool/));
                # don't look for add-on that was removed with MIGRATION_REMOVE_ADDONS
                next if (get_var('ZYPPER_LR') && get_var('MIGRATION_INCONSISTENCY_DEACTIVATE') && $scc_product =~ /$addon_removed/);
                # IDU and IDS don't have channels, repo is checked below
                next if ($scc_product eq 'SLE-IDU' || $scc_product eq 'SLE-IDS');
                validatelr(
                    {
                        product => $scc_product,
                        product_channel => $product_channel,
                        enabled_repo => ($product_channel =~ m{(Debuginfo|Source)}) ? "No" : "Yes",
                        uri => $uri,
                        version => $version
                    });
            }
        }

        # IBM DLPAR repos check for ppc64le
        if (exists $h_scc_addons{'SLE-IDU'}) {
            validatelr(
                {
                    product => 'IBM-DLPAR-utils',
                    enabled_repo => 'Yes',
                    uri => 'http://public.dhe.ibm'
                });
        }
        if (exists $h_scc_addons{'SLE-IDS'}) {
            validatelr(
                {
                    product => 'IBM-DLPAR-SDK',
                    enabled_repo => 'Yes',
                    uri => 'http://public.dhe.ibm'
                });
            validatelr(
                {
                    product => 'IBM-DLPAR-Adv-Toolchain',
                    enabled_repo => 'Yes',
                    uri => 'http://ftp.unicamp.br'
                });
        }

        # Check nvidia repo if SLED or sle-we extension registered
        # For the name of product channel, sle12 uses NVIDIA, sle12sp1 and sp2 use nVidia
        # Consider migration, use regex to match nvidia whether in upper, lower or mixed
        # Skip check AMD/ATI repo since it would be removed from sled12 and sle-we-12, see bsc#984866
        if ($base_product eq "SLED" || $we && !get_required_var('FLAVOR') =~ /-Updates$|-Incidents/) {
            validatelr(
                {
                    product => "SLE-",
                    product_channel => 'Desktop-[nN][vV][iI][dD][iI][aA]-Driver',
                    enabled_repo => 'Yes',
                    uri => $nvidia_uri,
                    version => $version
                });
        }
    }

    # zdup upgrade repo verification
    # s390x can't use dvd media, only works with network repo
    if (get_var('ZDUP')) {
        my $uri;
        if (get_var('TEST') =~ m{zdup_offline} and !is_s390x) {
            $uri = "$dvd:///";
        }
        else {
            $uri = "$utils::OPENQA_FTP_URL/SLE-";
        }
        validatelr(
            {
                product => "repo1",
                enabled_repo => "Yes",
                uri => $uri,
                version => $version
            });
    }
}

sub validate_repos {
    my ($version) = @_;
    $version //= get_var('VERSION');

    assert_script_run "zypper lr | tee /dev/$serialdev", 180;
    assert_script_run "zypper lr -d | tee /dev/$serialdev", 180;

    if (!get_var('STAGING') and is_sle('12-SP1+')) {
        validate_repos_sle($version);
    }
}

sub run {
    # ZYPPER_LR is needed for inconsistent migration, test would fail looking for deactivated addon
    set_var 'ZYPPER_LR', 1;
    select_serial_terminal;
    validate_repos;
}

1;
