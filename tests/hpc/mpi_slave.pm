# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: openmpi mpirun check
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use lockapi;
use utils;
use serial_terminal 'select_serial_terminal';
use testapi qw(record_info);
use POSIX 'strftime';

sub run ($self) {
    select_serial_terminal();
    my $mpi = $self->get_mpi();
    my %exports_path = (
        bin => '/home/bernhard/bin'
    );
    zypper_call("in $mpi-gnu-hpc");
    barrier_wait('CLUSTER_PROVISIONED');
    record_info 'CLUSTER_PROVISIONED', strftime("\%H:\%M:\%S", localtime);
    barrier_wait('MPI_SETUP_READY');
    record_info 'MPI_SETUP_READY', strftime("\%H:\%M:\%S", localtime);
    $self->mount_nfs_exports(\%exports_path);

    barrier_wait('MPI_BINARIES_READY');
    record_info 'MPI_BINARIES_READY', strftime("\%H:\%M:\%S", localtime);
    barrier_wait('MPI_RUN_TEST');
    record_info 'MPI_RUN_TEST', strftime("\%H:\%M:\%S", localtime);
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    $self->export_logs();
}

1;
