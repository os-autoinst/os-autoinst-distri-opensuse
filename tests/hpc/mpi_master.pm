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
    my $mpi = $self->get_mpi();
    my ($mpi_compiler, $mpi_c) = $self->get_mpi_src();
    my $mpi_bin = 'mpi_bin';
    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);

    ## adding required sdk and gcc
    if (is_sle '>=15') {
        add_suseconnect_product('sle-module-development-tools');
    }

    zypper_call("in $mpi $mpi-devel gcc gcc-c++ python3-devel");

    barrier_wait('CLUSTER_PROVISIONED');
    ## all nodes should be able to ssh to each other, as MPIs requires so
    $self->generate_and_distribute_ssh();

    barrier_wait('MPI_SETUP_READY');
    $self->check_nodes_availability();

    record_info('INFO', script_output('cat /proc/cpuinfo'));
    # re-export as the user is re-logged in
    assert_script_run("export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib64/mpi/gcc/$mpi/lib64/");
    $self->setup_scientific_module();
    my $hostname = get_var('HOSTNAME', 'susetest');
    record_info "hostname", "$hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run("export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib64/mpi/gcc/$mpi/lib64/");

    assert_script_run("wget --quiet " . data_url("hpc/$mpi_c") . " -O /tmp/$mpi_c");
    assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/$mpi_compiler /tmp/$mpi_c -o /tmp/$mpi_bin | tee /tmp/make.out") if $mpi_compiler;


    # python code is not compiled. *mpi_bin* is expected as a compiled binary. if compilation was not
    # invoked return source code (ex: sample_scipy.py).
    $mpi_bin = ($mpi_compiler) ? $mpi_bin : $mpi_c;
    ## distribute the binary
    foreach (@cluster_nodes) {
        assert_script_run("scp -o StrictHostKeyChecking=no /tmp/$mpi_bin root\@$_\:/tmp/$mpi_bin");
    }

    barrier_wait('MPI_BINARIES_READY');
    my $mpirun_s = hpc::formatter->new();

    unless ($mpi_bin eq '.cpp') {    # because calls expects minimum 2 nodes
        record_info('INFO', 'Run MPI over single machine');
        assert_script_run($mpirun_s->single_node("/tmp/$mpi_bin | tee /tmp/mpirun.out"));
    }

    record_info('INFO', 'Run MPI over several nodes');
    if ($mpi eq 'mvapich2') {
        # we do not support ethernet with mvapich2
        my $return = script_run("set -o pipefail;" . $mpirun_s->all_nodes("/tmp/$mpi_bin |& tee /tmp/mpi_bin.log"));
        if ($return == 143) {
            record_info("mvapich2 info", "echo $return - No IB device found");
        } elsif ($return == 139 || $return == 255) {
            # process running (on master return 139, on slave return 255)
            if (script_run('grep \'Caught error: Segmentation fault (signal 11)\' /tmp/mpi_bin.log') == 0) {
                record_soft_failure('bsc#1144000 MVAPICH2: segfault while executing without ib_uverbs loaded');
            }
        } else {
            ##TODO: condider more rebust handling of various errors
            die("echo $return - not expected errorcode");
        }
    } else {
        assert_script_run($mpirun_s->all_nodes('/tmp/$mpi_bin | tee /tmp/mpirun.out'));
    }

    barrier_wait('MPI_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    upload_logs('/tmp/make.out');
    upload_logs('/tmp/mpirun.out');
    upload_logs('/tmp/mpi_bin.log');
    $self->export_logs();
}

1;
