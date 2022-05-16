# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: openmpi mpirun check
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use lockapi;
use utils;

sub run ($self) {
    my $mpi = $self->get_mpi();
    my $exports_path = '/home/bernhard/bin';
    # Install required HPC dependencies on the nodes act as compute nodes
    my @hpc_deps = ('libucp0');
    push @hpc_deps, 'libhwloc15' if $mpi =~ m/mpich/;
    push @hpc_deps, ('libfabric1', 'libpsm2') if $mpi =~ m/openmpi/;
    push @hpc_deps, ('libibmad5') if $mpi =~ m/mvapich2/;
    zypper_call("in @hpc_deps");
    barrier_wait('CLUSTER_PROVISIONED');
    barrier_wait('MPI_SETUP_READY');
    $self->mount_nfs_exports($exports_path);

    barrier_wait('MPI_BINARIES_READY');
    barrier_wait('MPI_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) { }

1;
