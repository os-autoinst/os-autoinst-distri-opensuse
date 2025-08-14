# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Python2 module doesn't exist since SLE15SP3, need to remove it before migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use registration qw(remove_suseconnect_product get_addon_fullname);
use testapi qw(get_var set_var);

sub run {
    remove_suseconnect_product(get_addon_fullname('python2'));
    my $scc_addons = join ',',
      grep { $_ ne 'python2' } split(',', get_var('SCC_ADDONS'));
    set_var('SCC_ADDONS', $scc_addons);
}

1;
