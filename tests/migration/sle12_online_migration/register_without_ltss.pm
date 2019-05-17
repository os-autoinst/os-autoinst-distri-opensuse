# SLE12 online migration tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sle12 online migration testsuite
# Maintainer: Wei Jiang <wjiang@suse.com>

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
}

sub test_flags {
    return {fatal => 1};
}

1;
