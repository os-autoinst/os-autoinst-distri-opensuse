# SUSE's openQA tests
#
# Copyright SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Prepare RT system for migration to clear SCC status from previous
#          migration job runs
#            - do SCC cleanup
#            - register RT system
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run() {
    select_serial_terminal;
    assert_script_run 'SUSEConnect --cleanup';
    my $scc_regcode_rt = get_required_var 'SCC_REGCODE_RT';
    assert_script_run "SUSEConnect -r ${scc_regcode_rt}", timeout => 90;
}

sub test_flags {
    return {fatal => 1};
}
1;
