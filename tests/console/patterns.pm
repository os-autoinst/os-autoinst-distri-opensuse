# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
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
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # System roles are defined in config.xml. Currently the role 'kvm host'
    # defines kvm_server as an additional pattern, xen_server defines 'xen host'.
    die "Only kvm|xen roles are supported" unless get_var('SYSTEM_ROLE', '') =~ /kvm|xen/;
    my $pattern_name = get_required_var('SYSTEM_ROLE') . '_server';
    assert_script_run("zypper patterns -i | grep $pattern_name");
}

1;
