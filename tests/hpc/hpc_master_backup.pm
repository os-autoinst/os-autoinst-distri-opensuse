# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC master - backup master node
#    This test is aiming at comprehensive HPC testing. That means
#    that most components of the HPC product should be installed and
#    configured. At the same time it is expected that the HPC cluster
#    set-up is fairly complex, so that NFS shares are mounted, required
#    database(s) are ready to be used, artificial users are added etc.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::migration), -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;

sub run ($self) {
    my $nodes = get_required_var("CLUSTER_NODES");
    $self->prepare_user_and_group();

    # make sure products are registered; it might happen that the older SPs aren't
    # register with valid scc regcode
    if (get_var("HPC_MIGRATION")) {
        $self->register_products();
        barrier_wait("HPC_PRE_MIGRATION");
    }

    # provision HPC cluster, so the proper rpms are installed,
    # and all the set-up is done, including external services, like NFS etc.
    record_info('Start installing all components');
    zypper_call('in nfs-client rpcbind slurm slurm-munge ganglia-gmond');
    record_info('Installation done');

    record_info('System set-up: prepare needed configuration');
    $self->mount_nfs();
    barrier_wait("HPC_SETUPS_DONE");
    record_info('System set-up: enable & start services');
    barrier_wait("HPC_MASTER_SERVICES_ENABLED");

    $self->enable_and_start('gmond');
    systemctl("is-active gmond");
    $self->enable_and_start('munge');
    $self->enable_and_start('slurmctld');
    systemctl("is-active slurmctld");
    $self->enable_and_start('slurmd');
    systemctl("is-active slurmd");

    # wait for slave to be ready
    barrier_wait("HPC_SLAVE_SERVICES_ENABLED");
    barrier_wait('HPC_MASTER_RUN_TESTS');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmctld');
}

1;

