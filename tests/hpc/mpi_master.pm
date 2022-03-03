# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic MPI integration test. Checking for installability and
#     usability of MPI implementations, or HPC libraries. Using mpirun locally and across
#     available nodes. Test meant to be run in VMs, so thus using ethernet
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils);
use testapi;
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    my $mpi = $self->get_mpi();
    my ($mpi_compiler, $mpi_c) = $self->get_mpi_src();

    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);

    ## adding required sdk and gcc
    if (is_sle '>=15') {
        add_suseconnect_product('sle-module-development-tools');
    }

    zypper_call("in $mpi $mpi-devel gcc gcc-c++");
    assert_script_run("export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib64/mpi/gcc/$mpi/lib64/");

    barrier_wait('CLUSTER_PROVISIONED');
    ## all nodes should be able to ssh to each other, as MPIs requires so
    $self->generate_and_distribute_ssh();

    barrier_wait('MPI_SETUP_READY');
    $self->check_nodes_availability();

    record_info('INFO', script_output('cat /proc/cpuinfo'));

    assert_script_run("wget --quiet " . data_url("hpc/$mpi_c") . " -O /tmp/$mpi_c");
    assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/$mpi_compiler /tmp/$mpi_c -o /tmp/mpi_bin | tee /tmp/make.out");

    ## distribute the binary
    foreach (@cluster_nodes) {
        assert_script_run("scp -o StrictHostKeyChecking=no /tmp/mpi_bin root\@$_\:/tmp/mpi_bin");
    }
    barrier_wait('MPI_BINARIES_READY');

    unless (get_var('HPC_LIB', '') == 'boost') {
        record_info('INFO', 'Run MPI over single machine');
        ## openmpi requires non-root usr to run program or special flag '--allow-run-as-root'
        if ($mpi =~ m/openmpi/) {
            assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun --allow-run-as-root /tmp/mpi_bin");
        } else {
            assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun /tmp/mpi_bin | tee /tmp/mpirun.out");
        }
    }
    record_info('INFO', 'Run MPI over several nodes');
    if ($mpi =~ m/openmpi/) {
        assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun --allow-run-as-root --host $cluster_nodes  /tmp/mpi_bin");
    } elsif ($mpi eq 'mvapich2') {
        # we do not support ethernet with mvapich2
        my $return = script_run("set -o pipefail;/usr/lib64/mpi/gcc/$mpi/bin/mpirun --host $cluster_nodes /tmp/mpi_bin |& tee /tmp/mpi_bin.log");
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
        assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun -print-all-exitcodes --host $cluster_nodes /tmp/mpi_bin");
    }

    barrier_wait('MPI_RUN_TEST');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my $self = shift;
    upload_logs('/tmp/make.out');
    upload_logs('/tmp/mpirun.out');
    upload_logs('/tmp/mpi_bin.log');
    $self->export_logs();
}

1;
