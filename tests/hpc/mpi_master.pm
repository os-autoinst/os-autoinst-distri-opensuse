# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Basic MPI integration test. Checking for installability and
#     usability of mpirun and mpicc. Using mpirun locally and across
#     available nodes. Test meant to be run in VMs, so thus using ethernet
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

use base 'hpcbase';
use base 'hpc::utils';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';

sub run {
    my $self          = shift;
    my $mpi           = $self->get_mpi();
    my $mpi_c         = 'simple_mpi.c';
    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);

    ## adding required sdk and gcc
    if (is_sle '>=15') {
        add_suseconnect_product('sle-module-development-tools');
    }

    zypper_call("in $mpi $mpi-devel gcc");
    assert_script_run("export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib64/mpi/gcc/$mpi/lib64/");

    barrier_wait('CLUSTER_PROVISIONED');
    ## all nodes should be able to ssh to each other, as MPIs requires so
    $self->generate_and_distribute_ssh();

    barrier_wait('MPI_SETUP_READY');
    $self->check_nodes_availability();

    assert_script_run("wget --quiet " . data_url("hpc/$mpi_c") . " -O /tmp/$mpi_c");
    assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpicc /tmp/simple_mpi.c -o /tmp/simple_mpi | tee /tmp/make.out");

    ## distribute the binary
    foreach (@cluster_nodes) {
        assert_script_run("scp -o StrictHostKeyChecking=no /tmp/simple_mpi root\@$_\:/tmp/simple_mpi");
    }
    barrier_wait('MPI_BINARIES_READY');

    record_info('INFO', 'Run MPI over single machine');
    ## openmpi requires non-root usr to run program or special flag '--allow-run-as-root'
    if ($mpi =~ m/openmpi/) {
        assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun --allow-run-as-root /tmp/simple_mpi");
    } else {
        assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun /tmp/simple_mpi | tee /tmp/mpirun.out");
    }

    record_info('INFO', 'Run MPI over several nodes');
    if ($mpi =~ m/openmpi/) {
        assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun --allow-run-as-root --host $cluster_nodes  /tmp/simple_mpi");
    } elsif ($mpi eq 'mvapich2') {
        # we do not support ethernet with mvapich2
        my $return = script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun --host $cluster_nodes /tmp/simple_mpi");
        if ($return == 143) {
            record_info("echo $return - No IB device found");
        } else {
            ##TODO: condider more rebust handling of various errors
            die("echo $return - not expected errorcode");
        }
    } else {
        assert_script_run("/usr/lib64/mpi/gcc/$mpi/bin/mpirun --host $cluster_nodes /tmp/simple_mpi");
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
    $self->export_logs();
}

1;
