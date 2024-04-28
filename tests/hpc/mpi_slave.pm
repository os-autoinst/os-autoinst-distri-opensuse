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
use Utils::Logging 'export_logs';
use testapi;
use POSIX 'strftime';

sub run ($self) {
    select_serial_terminal();
    my $mpi = get_required_var('MPI');
    my %exports_path = (
        bin => '/home/bernhard/bin'
    );
    zypper_call("in $mpi-gnu-hpc");
    barrier_wait('CLUSTER_PROVISIONED');
    record_info 'CLUSTER_PROVISIONED', strftime("\%H:\%M:\%S", localtime);
    barrier_wait('MPI_SETUP_READY');
    record_info 'MPI_SETUP_READY', strftime("\%H:\%M:\%S", localtime);
    $self->mount_nfs_exports(\%exports_path);
    $self->setup_scientific_module();
    barrier_wait('MPI_BINARIES_READY');
    record_info 'MPI_BINARIES_READY', strftime("\%H:\%M:\%S", localtime);
    barrier_wait('MPI_RUN_TEST');
    record_info 'MPI_RUN_TEST', strftime("\%H:\%M:\%S", localtime);
    if (check_var('IMB', 'RUN')) {
        barrier_wait('IMB_TEST_DONE');
    }
    if (check_var('HDF5', 'RUN')) {
        barrier_wait('HDF5_RUN_TEST');
    }
    if (check_var('SCIPY', 'RUN')) {
        zypper_call("in python3-scipy-gnu-hpc python3-devel $mpi-gnu-hpc-devel");

        # Make sure that env is updated. This will run scripts like 'source /usr/share/lmod/lmod/init/bash'
        $self->relogin_root;
        my $mpi2load = ($mpi =~ /openmpi2|openmpi3|openmpi4/) ? 'openmpi' : $mpi;
        assert_script_run "module load gnu $mpi2load python3-scipy";
        assert_script_run("env MPICC=mpicc python3 -m pip install mpi4py", timeout => 1200);

        barrier_wait('SCIPY_RUN_TEST');
    }
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    export_logs();
}

1;
