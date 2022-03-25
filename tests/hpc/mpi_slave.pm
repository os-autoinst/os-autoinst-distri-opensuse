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
    zypper_call("in $mpi $mpi-devel gcc gcc-c++ python3-devel");
    $self->setup_scientific_module();
    assert_script_run("export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib64/mpi/gcc/$mpi/lib64/");
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
