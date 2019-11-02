# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm master
#    This test is setting up slurm masters for checking failover
#    for the ctl slurm nodes
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

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

    zypper_call('in slurm slurm-munge');

    $self->mount_nfs();
    $self->prepare_slurm_conf();
    barrier_wait("SLURM_SETUP_DONE");
    record_info('slurmctl conf', script_output('cat /etc/slurm/slurm.conf'));

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

    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    assert_script_run("srun -N ${nodes} /bin/ls");
    assert_script_run("sinfo -N -l");
    assert_script_run("scontrol ping");

    # backup ctl takes over
    assert_script_run("scontrol takeover");
    assert_script_run("scontrol ping");

    assert_script_run("srun -w slave-node00 date");
    assert_script_run("srun -w slave-node01 date");
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
