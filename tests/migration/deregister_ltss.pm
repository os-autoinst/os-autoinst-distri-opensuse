# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: LTSS is not supported to do migration, need to deregiter it before migration
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use registration qw(remove_suseconnect_product);
use testapi qw(get_var set_var);

sub run {
    remove_suseconnect_product('SLES-LTSS');
    my $scc_addons = join ',',
      grep { $_ ne 'ltss' } split(',', get_var('SCC_ADDONS'));
    set_var('SCC_ADDONS', $scc_addons);
}

1;
