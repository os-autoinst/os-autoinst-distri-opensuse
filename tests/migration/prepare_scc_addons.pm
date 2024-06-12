# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Swap the values of SCC_ADDONS before migration.
#
# In migration maintenance updates tests, SCC_ADDONS is used for both
# registering original system and adding target system modules maintenance
# updates repos. But for SLE 12 and SLE 15, the modules name are different.
# So swap SCC_ADDONS values to upgraded SLE 15 modules before migration.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    set_var('SCC_ADDONS', get_var('SCC_ADDONS_2'));
}

1;
