# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Initialization of barriers for HPC multimachine tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest', -signatures;
use testapi;
use lockapi;
use utils;

sub run ($self) {
    # Get number of nodes
    my $nodes = get_required_var('CLUSTER_NODES');
    record_info("#barriers", $nodes);
    # Initialize barriers
    if (check_var('HPC', 'slurm')) {
        barrier_create('CLUSTER_PROVISIONED', $nodes);
        barrier_create('SLURM_MASTER_SERVICE_ENABLED', $nodes);
        barrier_create('SLURM_SLAVE_SERVICE_ENABLED', $nodes);
        barrier_create('SLURM_SETUP_DONE', $nodes);
        barrier_create('SLURM_MASTER_RUN_TESTS', $nodes);
        barrier_create('SLURM_SETUP_DBD', $nodes);
    }
    elsif (check_var('HPC', 'mrsh')) {
        barrier_create('MRSH_INSTALLATION_FINISHED', $nodes);
        barrier_create('MRSH_KEY_COPIED', $nodes);
        barrier_create('MRSH_MUNGE_ENABLED', $nodes);
        barrier_create('SLAVE_MRLOGIN_STARTED', $nodes);
        barrier_create('MRSH_MASTER_DONE', $nodes);
    }
    elsif (check_var('HPC', 'munge')) {
        barrier_create('MUNGE_INSTALLATION_FINISHED', $nodes);
        barrier_create('MUNGE_KEY_COPIED', $nodes);
        barrier_create('MUNGE_SERVICE_ENABLED', $nodes);
        barrier_create('MUNGE_DONE', $nodes);
    }
    elsif (check_var('HPC', 'pdsh')) {
        barrier_create('PDSH_INSTALLATION_FINISHED', $nodes);
        barrier_create('PDSH_KEY_COPIED', $nodes);
        barrier_create('PDSH_MUNGE_ENABLED', $nodes);
        barrier_create('MRSH_SOCKET_STARTED', $nodes);
        barrier_create('PDSH_SLAVE_DONE', $nodes);
    }
    elsif (check_var('HPC', 'dolly')) {
        barrier_create('DOLLY_INSTALLATION_FINISHED', $nodes);
        barrier_create('DOLLY_SERVER_READY', $nodes);
        barrier_create('DOLLY_DONE', $nodes);
    }
    elsif (check_var('HPC', 'ganglia')) {
        barrier_create('GANGLIA_INSTALLED', $nodes);
        barrier_create('GANGLIA_SERVER_DONE', $nodes);
        barrier_create('GANGLIA_CLIENT_DONE', $nodes);
        barrier_create('GANGLIA_GMETAD_STARTED', $nodes);
        barrier_create('GANGLIA_GMOND_STARTED', $nodes);
    }
    elsif (check_var('HPC', 'mpi')) {
        barrier_create('CLUSTER_PROVISIONED', $nodes);
        barrier_create('MPI_SETUP_READY', $nodes);
        barrier_create('MPI_BINARIES_READY', $nodes);
        barrier_create('MPI_RUN_TEST', $nodes);
        barrier_create('IMB_TEST_DONE', $nodes);
    }
    elsif (check_var('HPC', 'ww4_controller')) {
        barrier_create('WWCTL_DONE', $nodes);
        barrier_create('WWCTL_COMPUTE_DONE', $nodes);
    }
    elsif (check_var('HPC', 'hpc_comprehensive')) {
        if (get_var('HPC_MIGRATION')) {
            barrier_create('HPC_PRE_MIGRATION', $nodes);
        }
        barrier_create('HPC_MASTER_SERVICES_ENABLED', $nodes);
        barrier_create('HPC_SLAVE_SERVICES_ENABLED', $nodes);
        barrier_create('HPC_SETUPS_DONE', $nodes);
        barrier_create('HPC_MASTER_RUN_TESTS', $nodes);
        if (get_var('HPC_MIGRATION')) {
            barrier_create('HPC_MIGRATION_START', $nodes);
            barrier_create('HPC_MIGRATION_TESTS', $nodes);
            barrier_create('HPC_POST_MIGRATION_TESTS', $nodes);
            barrier_create('HPC_POST_MIGRATION_TESTS_RUN', $nodes);
        }
    }
    else {
        die('Unsupported test, check content of HPC variable');
    }
    record_info('barriers initialized');
}

sub test_flags ($self) {
    return {fatal => 1};
}

1;
