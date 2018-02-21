# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm slave
#    This test is setting up a slurm slave and tests if the daemon can start
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/316379, https://progress.opensuse.org/issues/20308

use base "hpcbase";
use strict;
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;

    # Synchronize with master
    mutex_lock("SLURM_MASTER_BARRIERS_CONFIGURED");
    mutex_unlock("SLURM_MASTER_BARRIERS_CONFIGURED");

    # Stop firewall
    systemctl 'stop ' . $self->firewall;

    # Install slurm
    zypper_call('in slurm-munge');

    barrier_wait("SLURM_SETUP_DONE");
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");

    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmd
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    mutex_lock("SLURM_MASTER_RUN_TESTS");
    mutex_unlock("SLURM_MASTER_RUN_TESTS");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
