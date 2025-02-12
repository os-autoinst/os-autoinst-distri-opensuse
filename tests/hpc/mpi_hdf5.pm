# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Name: Basic MPI HDF5 test
# Summary: The test module does basic HDF5 testing by installing required
#     packages and then running basic HDF5 hello world example
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
    select_serial_terminal();
    my $mpi = get_required_var('MPI');
    my $mpi_compiler = 'mpicc';
    my $mpi_c = 'h5_write.c';
    my $mpi_bin = 'mpi_bin_hdf5';
    my %exports_path = (
        bin => '/home/bernhard/bin',
        hpc_lib => '/usr/lib/hpc',
    );
    my $mpi2load = '';
    #my @cluster_nodes = $self->cluster_names();
    #my $cluster_nodes = join(',', @cluster_nodes);
    my $mpirun_s = hpc::formatter->new();
    my $user_virtio_fixed = isotovideo::get_version() >= 35;
    my $prompt = $user_virtio_fixed ? $testapi::username . '@' . get_required_var('HOSTNAME') . ':~> ' : undef;

    zypper_call("in hdf5-gnu-hpc hdf5-gnu-hpc-devel");

    type_string('pkill -u root', lf => 1) unless $user_virtio_fixed;
    select_user_serial_terminal($prompt);
    # for <15-SP2 the openmpi2 module is named openmpi
    $mpi2load = ($mpi =~ /openmpi2|openmpi3|openmpi4/) ? 'openmpi' : $mpi;

    assert_script_run("wget --quiet " . data_url("hpc/$mpi_c") . " -O $exports_path{'bin'}/$mpi_c");

    # And login as normal user to run the tests
    # NOTE: This behaves weird. Need another solution apparently
    type_string('pkill -u root') unless $user_virtio_fixed;
    select_user_serial_terminal($prompt);
    # load mpi after all the relogins
    my @load_modules = $mpi2load;
    assert_script_run "module load gnu @load_modules hdf5";
    script_run "module av";

    my $version = script_output("module whatis hdf5 | grep Version");
    record_info('HDF5 version', $version);
    $version = (split(/: /, $version))[2];
    assert_script_run("$mpi_compiler -o $exports_path{'bin'}/$mpi_bin $exports_path{'bin'}/$mpi_c -Iexports_path{'hpc'}/gnu7/hdf5/$version/include -Iexports_path{'hpc'}/gnu7/hdf5/$version/lib64 -lhdf5");
    record_info('LD', $LD_LIBRARY_PATH);
    assert_script_run($mpirun_s->all_nodes("$exports_path{'bin'}/$mpi_bin"), timeout => 120);
    assert_script_run("test -s /home/bernhard/$mpi_bin");
    script_run("rm  /home/bernhard/$mpi_bin");
    barrier_wait('HDF5_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    export_logs();
}

1;
