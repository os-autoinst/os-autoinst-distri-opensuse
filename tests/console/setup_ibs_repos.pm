# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Replace osd SLFO repos with ibs repos
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use testapi;
use utils qw(zypper_call);
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;

    assert_script_run('SUSEConnect -d || SUSEConnect --cleanup');
    zypper_call('lr -u', exitcode => [0, 6]);
    zypper_call('ar -f http://dist.suse.de/ibs/SUSE:/SLFO:/Products:/SLES:/16.0:/TEST/product/repo/SLES-16.0-' . get_var('ARCH') . ' SLES::16.0::product');
    zypper_call('lr -u');
}

sub test_flags {
    return {fatal => 1};
}

1;
