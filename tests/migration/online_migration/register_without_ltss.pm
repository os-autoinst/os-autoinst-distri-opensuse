# SLE12 online migration tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: SUSEConnect zypper yast2-registration
# Summary: sle12 online migration testsuite
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use registration;
use migration;

sub run {
    select_console 'root-console';

    scc_deregistration(version_variable => 'HDDVERSION');

    # Re-register system without LTSS with resetting SCC_ADDONS variable without ltss
    my @scc_addons = split(/,/, get_var('SCC_ADDONS', ''));
    @scc_addons = grep { $_ ne 'ltss' } @scc_addons;
    set_var('SCC_ADDONS', join(',', @scc_addons));

    register_system_in_textmode;

    # Sometimes in HA scenario, we need to test rolling upgrade migration from
    # a LTSS version to another one LTSS version.
    # In this case, we need to add ltss again to SCC_ADDONS and set HDDVERSION to
    # the targeted OS version for getting the good LTSS regcode.
    if (get_var('LTSS_TO_LTSS')) {
        set_var('SCC_ADDONS', join(',', @scc_addons, 'ltss'));
        set_var('HDDVERSION', get_var('UPGRADE_TARGET_VERSION', get_var('VERSION')));
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
