# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialization of barriers for HPC multimachine tests
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");

    # Initialize barriers
    if (check_var("HPC", "slurm")) {
        barrier_create("SLURM_MASTER_SERVICE_ENABLED", $nodes);
        barrier_create("SLURM_SLAVE_SERVICE_ENABLED",  $nodes);
        barrier_create("SLURM_SETUP_DONE",             $nodes);
        barrier_create('SLURM_MASTER_RUN_TESTS',       $nodes);
    }
    elsif (check_var("HPC", "mrsh")) {
        barrier_create("MRSH_INSTALLATION_FINISHED", $nodes);
        barrier_create("MRSH_KEY_COPIED",            $nodes);
        barrier_create("MRSH_MUNGE_ENABLED",         $nodes);
        barrier_create("SLAVE_MRLOGIN_STARTED",      $nodes);
        barrier_create("MRSH_MASTER_DONE",           $nodes);
    }
    elsif (check_var("HPC", "munge")) {
        barrier_create("MUNGE_INSTALLATION_FINISHED", $nodes);
        barrier_create('MUNGE_KEY_COPIED',            $nodes);
        barrier_create("MUNGE_SERVICE_ENABLED",       $nodes);
        barrier_create('MUNGE_DONE',                  $nodes);
    }
    elsif (check_var("HPC", "pdsh")) {
        barrier_create("PDSH_INSTALLATION_FINISHED", $nodes);
        barrier_create("PDSH_KEY_COPIED",            $nodes);
        barrier_create("PDSH_MUNGE_ENABLED",         $nodes);
        barrier_create("MRSH_SOCKET_STARTED",        $nodes);
        barrier_create("PDSH_SLAVE_DONE",            $nodes);
    }
    elsif (check_var("HPC", "ganglia")) {
        barrier_create("GANGLIA_INSTALLED",      $nodes);
        barrier_create("GANGLIA_SERVER_DONE",    $nodes);
        barrier_create("GANGLIA_CLIENT_DONE",    $nodes);
        barrier_create("GANGLIA_GMETAD_STARTED", $nodes);
        barrier_create("GANGLIA_GMOND_STARTED",  $nodes);
    }
    elsif (check_var("HPC", "mpi")) {
        barrier_create("MPI_SETUP_READY",    $nodes);
        barrier_create("MPI_BINARIES_READY", $nodes);
        barrier_create("MPI_RUN_TEST",       $nodes);
    }
    elsif (check_var("HPC", "hpc_comprehensive")) {
        barrier_create("HPC_MASTER_SERVICES_ENABLED", $nodes);
        barrier_create("HPC_SLAVE_SERVICES_ENABLED",  $nodes);
        barrier_create("HPC_SETUPS_DONE",             $nodes);
        barrier_create("HPC_MASTER_RUN_TESTS",        $nodes);
    }
    else {
        die("Unsupported test, check content of HPC variable");
    }
    record_info("barriers initialized");
}

sub test_flags {
    return {fatal => 1};
}

1;
