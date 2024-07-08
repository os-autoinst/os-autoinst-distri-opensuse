# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Set environmental variables which differ between the products involved in the upgrade
# with the possibility to restore it later.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use migration 'reset_consoles_tty';

sub run {
    # Read product variables of the product to migrate from/to
    my $version = get_var('VERSION_UPGRADE_FROM', get_var('VERSION_UPGRADE_TO'));
    my $scc_addons =
      get_var('SCC_ADDONS_UPGRADE_FROM',
        get_var('SCC_ADDONS_UPGRADE_TO',
            get_var('SCC_ADDONS')));

    # Save the original value of the variables in order to restore it later if needed
    set_var('VERSION_ENV', get_var('VERSION'));
    set_var('SCC_ADDONS_ENV', get_var('SCC_ADDONS'));

    # Change variables to the other version that we want to migrate from/to
    set_var('VERSION', $version);
    record_info('VERSION', 'VERSION=' . get_var('VERSION'));
    set_var('SCC_ADDONS', $scc_addons);
    record_info('SCC_ADDONS', 'SCC_ADDONS=' . get_var('SCC_ADDONS'));

    # tty assignation might differ between product versions
    reset_consoles_tty();

    # Boot from Hard Disk will not be selected in boot screen
    set_var('BOOT_HDD_IMAGE', 0);
}

1;
