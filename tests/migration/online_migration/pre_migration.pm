# SLE12 online migration tests
#
# Copyright 2016-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: btrfsprogs zypper
# Summary: sle12 online migration testsuite
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;
use Utils::Architectures;
use Utils::Backends;
use utils;
use migration;
use version_utils;
use x11utils 'turn_off_gnome_show_banner';

sub check_or_install_packages {
    assert_script_run('modprobe nvram') if is_pvm_hmc;
    if (get_var("FULL_UPDATE") || get_var("MINIMAL_UPDATE")) {
        # if system is fully updated or even minimal patch applied,
        # all necessary packages for online migration should be installed.
        my @pkgs = qw(yast2-migration rollback-helper);
        assert_script_run("rpm -q $_") foreach @pkgs;
    } else {
        # install necessary packages for online migration if system is not updated
        # also update snapper to ensure rollback service work properly after migration
        zypper_call "in yast2-migration zypper-migration-plugin rollback-helper snapper";
    }
}

sub remove_kgraft_patch {
    if (get_var('SCC_ADDONS')) {
        for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
            if ($addon eq 'live') {
                zypper_call('rm $(rpm -qa kgraft-patch-*)');
                record_soft_failure 'bsc#985647: [online migration] Conflict on kgraft-patch-3_12_57 when doing SCC online migration with Live Patching addon';
            }
        }
    }
}

sub run {
    select_console 'root-console';

    set_zypp_single_rpmtrans();
    check_or_install_packages unless is_leap_migration;

    # set scc proxy url here to perform online migration via scc proxy
    set_scc_proxy_url;

    # import gpg key
    script_run("rpm --import /usr/lib/rpm/gnupg/keys/gpg-pubkey-*.asc");
    # according to comment 19 of bsc#985647, uninstall all kgraft-patch* packages prior to migration as a workaround to
    # solve conflict during online migration with live patching addon
    remove_kgraft_patch if is_sle('<15');
    # create btrfs subvolume for aarch64 before migration
    create_btrfs_subvolume() if (is_aarch64);
    # We need to close gnome notification banner before migration.
    if (check_var('DESKTOP', 'gnome')) {
        select_console 'user-console';
        turn_off_gnome_show_banner;
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
