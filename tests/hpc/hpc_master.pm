# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC master
#    This test is aiming at comprehensive HPC testing. That means
#    that most components of the HPC product should be installed and
#    configured. At the same time it is expected that the HPC cluster
#    set-up is fairly complex, so that NFS shares are mounted, required
#    database(s) are ready to be used, some data is being populated to
#    the databases, artificial users are added etc.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::configs hpc::migration), -signatures;
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

    my $registration_status = script_output("SUSEConnect --status-text");
    record_info('INFO', "$registration_status");

    # provision HPC cluster, so the proper rpms are installed,
    # and all the set-up is done, including external services, like NFS etc.
    record_info('Start installing all components');
    zypper_call('in slurm slurm-munge ganglia-gmetad ganglia-gmond ganglia-gmetad-skip-bcheck');
    zypper_call('in nfs-client rpcbind');
    record_info('Installation done');

    record_info('System set-up: prepare needed configuration');
    $self->mount_nfs();
    $self->prepare_slurm_conf();
    record_info('slurmctl conf', script_output('cat /etc/slurm/slurm.conf'));
    barrier_wait("HPC_SETUPS_DONE");

    record_info('System set-up: enable & start services');
    $self->generate_and_distribute_ssh();
    $self->distribute_munge_key();
    $self->distribute_slurm_conf();
    $self->enable_and_start("munge");
    systemctl("is-active munge");
    $self->enable_and_start("slurmctld");
    systemctl("is-active slurmctld");
    $self->enable_and_start("slurmd");
    systemctl("is-active slurmd");
    $self->enable_and_start("gmetad");
    systemctl("is-active gmetad");
    record_info('System set-up: finished');

    # wait for slave nodes to be ready
    barrier_wait("HPC_MASTER_SERVICES_ENABLED");
    $self->enable_and_start("gmond");
    systemctl("is-active gmond");
    barrier_wait("HPC_SLAVE_SERVICES_ENABLED");

    ## Check if all nodes are pingable
    $self->check_nodes_availability();

    # run basic test against first compute node
    assert_script_run('sinfo -N -l');
    assert_script_run('sinfo  -o \"%P %.10G %N\"');

    ## TODO: Add multi-component tests, i.e. mpirun jobs scheduled with slurm
    # and scheduled by various users AND check if they are recorded well in the db

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
    $self->upload_service_log('slurmdbd');
    upload_logs('/var/log/slurmctld.log');
}

1;
