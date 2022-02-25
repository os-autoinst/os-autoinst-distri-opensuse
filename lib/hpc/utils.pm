# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provide functionality for hpc tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package hpc::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub get_mpi() {
    my $mpi = get_required_var('MPI');

    if ($mpi eq 'openmpi3') {
        if (is_sle('<15')) {
            $mpi = 'openmpi';
        } elsif (is_sle('<15-SP2')) {
            $mpi = 'openmpi2';
        }
    }

    return $mpi;
}

=head2 get_mpi_src

 get_mpi_src();

Returns the source code which is used based on B<HPC_LIB> job variable. The variable indicates the HPC library
which the mpi use to compile the source code. if the variable is not set, one of the other MPI implementations
will be used(mpich, openmpi, mvapich2).

Returns an array with the mpi compiler and the source code located in /data/hpc

=cut
sub get_mpi_src {
    return ('mpicc', 'simple_mpi.c') unless get_var('HPC_LIB', '');
    return ('mpic++', 'sample_boost.cpp') if (get_var('HPC_LIB') == 'boost');
}

1;
