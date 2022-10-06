# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic MPI integration test. Checking for installability and
#     usability of MPI implementations, or HPC libraries. Using mpirun locally and across
#     available nodes. Test meant to be run in VMs, so thus using ethernet
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';
use hpc::formatter;

sub run ($self) {
    $self->select_serial_terminal();
    my $mpi = $self->get_mpi();
    my ($mpi_compiler, $mpi_c) = $self->get_mpi_src();
    my $mpi_bin = 'mpi_bin';
    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);
    my %exports_path = (
        bin => '/home/bernhard/bin',
        hpc_lib => '/usr/lib/hpc',
    );
    script_run("sudo -u $testapi::username mkdir $exports_path{bin}");
    zypper_call("in $mpi-gnu-hpc $mpi-gnu-hpc-devel python3-devel");
    my $need_restart = $self->setup_scientific_module();
    $self->relogin_root if $need_restart;
    $self->setup_nfs_server(\%exports_path);

    type_string('pkill -u root', lf => 1);
    $self->select_serial_terminal(0);
    # for <15-SP2 the openmpi2 module is named simply openmpi
    $mpi = 'openmpi' if ($mpi =~ /openmpi2|openmpi3|openmpi4/);

    barrier_wait('CLUSTER_PROVISIONED');
    ## all nodes should be able to ssh to each other, as MPIs requires so
    $self->generate_and_distribute_ssh($testapi::username);
    $self->check_nodes_availability();

    record_info('INFO', script_output('cat /proc/cpuinfo'));
    my $hostname = get_var('HOSTNAME', 'susetest');
    record_info "hostname", "$hostname";
    assert_script_run "hostnamectl status | grep $hostname";
    assert_script_run("wget --quiet " . data_url("hpc/$mpi_c") . " -O $exports_path{'bin'}/$mpi_c");

    # I need to restart the nfs-server for some reason otherwise the compute nodes
    # cannot mount directories
    select_console('root-console');
    systemctl 'restart nfs-server';
    # And login as normal user to run the tests
    type_string('pkill -u root');
    $self->select_serial_terminal(0);
    # load mpi after all the relogins
    assert_script_run "module load gnu $mpi";
    script_run "module av";

    barrier_wait('MPI_SETUP_READY');
    assert_script_run("$mpi_compiler $exports_path{'bin'}/$mpi_c -o $exports_path{'bin'}/$mpi_bin") if $mpi_compiler;

    # python code is not compiled. *mpi_bin* is expected as a compiled binary. if compilation was not
    # invoked return source code (ex: sample_scipy.py).
    $mpi_bin = ($mpi_compiler) ? $mpi_bin : $mpi_c;
    barrier_wait('MPI_BINARIES_READY');
    my $mpirun_s = hpc::formatter->new();

    unless ($mpi_bin eq '.cpp') {    # because calls expects minimum 2 nodes
        record_info('INFO', 'Run MPI over single machine');
        if ($mpi eq 'mvapich2') {
            # mvapich2/2.2 known issue
            my $return = script_run("set -o pipefail;" . $mpirun_s->single_node("$exports_path{'bin'}/$mpi_bin |& tee /tmp/mpi_bin.log"), timeout => 120);
            if (script_run('grep \'invalid error code ffffffff\' /tmp/mpi_bin.log') == 0) {
                record_soft_failure('bsc#1199811 known problem on single core on mvapich2/2.2');
            }
        } else {
            assert_script_run($mpirun_s->single_node("$exports_path{'bin'}/$mpi_bin"), timeout => 120);
        }
    }

    record_info('INFO', 'Run MPI over several nodes');
    if ($mpi eq 'mvapich2') {
        # we do not support ethernet with mvapich2
        my $return = script_run("set -o pipefail;" . $mpirun_s->all_nodes("$exports_path{'bin'}/$mpi_bin |& tee /tmp/mpi_bin.log"), timeout => 120);
        if ($return == 143) {
            record_info("mvapich2 info", "echo $return - No IB device found", result => 'softfail');
        } elsif ($return == 139 || $return == 255) {
            # process running (on master return 139, on slave return 255)
            if (script_run('grep \'Caught error: Segmentation fault (signal 11)\' /tmp/mpi_bin.log') == 0) {
                record_soft_failure('bsc#1144000 MVAPICH2: segfault while executing without ib_uverbs loaded');
            }
        } elsif ($return == 136) {
            if (script_run('grep \'Caught error: Floating point exception (signal 8)\' /tmp/mpi_bin.log') == 0) {
                record_soft_failure('bsc#1175679 Floating point exception should be fixed on mvapich2/2.3.4');
            }
        } else {
            ##TODO: condider more rebust handling of various errors
            die("echo $return - not expected errorcode");
        }
    } else {
        assert_script_run($mpirun_s->all_nodes("$exports_path{'bin'}/$mpi_bin"), timeout => 120);
    }
    barrier_wait('MPI_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    $self->export_logs();
}

1;
