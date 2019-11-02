# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm master
#    This test is setting up slurm master and starts the control node
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>
# Tags: https://fate.suse.com/316379, https://progress.opensuse.org/issues/20308

use base 'hpcbase';
use base 'hpc::configs';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self  = shift;
    my $nodes = get_required_var("CLUSTER_NODES");
    $self->prepare_user_and_group();

    # install slurm
    zypper_call('in slurm slurm-munge');

    $self->prepare_slurm_conf();
    barrier_wait("SLURM_SETUP_DONE");

    $self->distribute_munge_key();
    $self->distribute_slurm_conf();

    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmctld
    $self->enable_and_start('slurmctld');
    systemctl 'status slurmctld';

    # enable and start slurmd since maester also acts as Node here
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';

    # wait for slave to be ready
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    # run the actual test against both nodes
    assert_script_run("srun -N ${nodes} /bin/ls");

    barrier_wait('SLURM_MASTER_RUN_TESTS');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmctld');
}

1;
