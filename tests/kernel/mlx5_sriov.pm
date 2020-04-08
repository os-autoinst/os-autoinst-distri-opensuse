# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure SR-IOV for Mellanox ConnectX-5
# Maintainer: Michael Moese <mmoese@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    $self->select_serial_terminal;

    # ensure ib_ipoib is loaded
    assert_script_run('modprobe ib_ipoib');
    zypper_call('in infiniband-diags bc');
    save_screenshot;

    script_run('wget --quiet ' . data_url('kernel/mlx5_sriov.sh') . ' -O mlx5_sriov.sh');
    save_screenshot;
    script_run('chmod +x mlx5_sriov.sh');
    save_screenshot;
    script_run('./mlx5_sriov.sh');
    save_screenshot;
}

1;
