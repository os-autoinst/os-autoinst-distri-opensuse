# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: openmpi mpirun check
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

use Mojo::Base qw(hpcbase hpc::utils);
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;
    my $mpi = $self->get_mpi();

    zypper_call("in $mpi");

    barrier_wait('CLUSTER_PROVISIONED');
    barrier_wait('MPI_SETUP_READY');
    barrier_wait('MPI_BINARIES_READY');
    barrier_wait('MPI_RUN_TEST');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
}

1;
