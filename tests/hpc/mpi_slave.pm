# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: openmpi mpirun check
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use lockapi;
use utils;

sub run ($self) {
    my $mpi = $self->get_mpi();

    # python3-devel is used to install and compile /mpi4py/ deps when HPC_LIB eq scipy
    zypper_call("in $mpi-gnu-hpc $mpi-gnu-hpc-devel python3-devel");
    my $need_restart = $self->setup_scientific_module();
    $self->relogin_root if $need_restart;
    # for <15-SP2 the openmpi2 module is named simply openmpi
    $mpi = 'openmpi' if ($mpi =~ /openmpi2|openmpi3|openmpi4/);
    assert_script_run "module load gnu $mpi";
    barrier_wait('CLUSTER_PROVISIONED');
    barrier_wait('MPI_SETUP_READY');
    barrier_wait('MPI_BINARIES_READY');
    barrier_wait('MPI_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) { }

1;
