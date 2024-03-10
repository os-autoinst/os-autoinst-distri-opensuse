# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Name: Basic MPI HDF5 test
# Description: The test module does basic HDF5 testing by installing required
# packages and then running basic HDF5 hello world example
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use lockapi;
use utils;
use registration;
use Utils::Logging 'export_logs';
use hpc::formatter;

sub run ($self) {
    record_info('TODO', 'Write simple test');
    zypper_call("in hdf5-gnu-hpc hdf5-gnu-hpc-devel");
    $self->relogin_root;
    assert_script_run("module load gnu openmpi hdf5");
    my $version = script_output("module whatis hdf5 | grep Version");
    $version = (split(/: /, $version))[2];
    #assert_script_run("$mpi_compiler -o $exports_path{'bin'}/$mpi_bin $exports_path{'bin'}/$mpi_c -Iexports_path{'hpc'}/gnu7/hdf5/$version/include -Iexports_path{'hpc'}/gnu7/hdf5/$version/lib64 -lhdf5");

}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    export_logs();
}

1;
