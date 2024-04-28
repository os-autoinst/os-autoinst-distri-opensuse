# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Name: Basic SCIPY test
# Summary: The test module does basic SCIPY testing by installing required
#     packages and then running basic SCIPY hello world example
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use lockapi;
use utils;
use registration;
use Utils::Logging 'export_logs';

sub run ($self) {
    select_serial_terminal();
    my $mpi = get_required_var('MPI');
    my $mpi_compiler = 'mpicc';
    my $mpi_c = 'sample_scipy.py';
    my $mpi_bin = 'sample_scipy.py';
    my %exports_path = (
        bin => '/home/bernhard/bin',
        hpc_lib => '/usr/lib/hpc',
    );
    my $mpi2load = '';
    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);

    my $user_virtio_fixed = isotovideo::get_version() >= 35;
    my $prompt = $user_virtio_fixed ? $testapi::username . '@' . get_required_var('HOSTNAME') . ':~> ' : undef;

    zypper_call("in python3-scipy-gnu-hpc python3-devel");

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
    assert_script_run "module load gnu @load_modules python3-scipy";
    assert_script_run("env MPICC=mpicc python3 -m pip install mpi4py", timeout => 1200);
    script_run "module av";

    assert_script_run("mpirun --host $cluster_nodes python3 $exports_path{'bin'}/$mpi_bin");
    barrier_wait('SCIPY_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    export_logs();
}

1;
