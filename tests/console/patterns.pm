# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test pattern selection for system role 'kvm host'
# Maintainer: Christopher Hofmann <cwh@suse.de>
# Tags: fate#317481 poo#16650

use base 'consoletest';
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    # System roles are defined in config.xml. Currently the role 'kvm host'
    # defines kvm_server as an additional pattern, xen_server defines 'xen host'.
    my $pattern_name = 'kvm_server';
    if (check_var('SYSTEM_ROLE', 'xen')) {
        $pattern_name = 'xen_server';
    }
    assert_script_run("zypper patterns -i | grep $pattern_name");
}

1;
# vim: set sw=4 et:
