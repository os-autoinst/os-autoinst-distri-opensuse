# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sle12 online migration testsuite
# Maintainer: yutao <yuwang@suse.com>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use migration;
use registration "scc_deregistration";

sub run {
    select_console 'root-console';

    # Sometimes in HA scenario, we need to test rolling upgrade migration from
    # a LTSS version to another one LTSS version.
    # In this case, we need to deregister the system and register it again for adding the
    # LTSS of the targeted OS version.
    scc_deregistration if get_var('LTSS_TO_LTSS');

    register_system_in_textmode;
}

sub test_flags {
    return {fatal => 1};
}

1;
