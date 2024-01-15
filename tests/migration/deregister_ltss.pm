# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: LTSS is not supported to do migration, need to deregiter it before migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use registration qw(remove_suseconnect_product);
use testapi qw(get_var set_var);

sub run {
    remove_suseconnect_product('SLES-LTSS');
    my $scc_addons = join ',',
      grep { $_ ne 'ltss' } split(',', get_var('SCC_ADDONS'));
    set_var('SCC_ADDONS', $scc_addons);
}

1;
