# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: HPC_Module: Client nodes of a cluster with Spack
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use lockapi;
use utils;

sub run ($self) {
    my $mpi = $self->get_mpi();
    $self->prepare_spack_env($mpi);
    assert_script_run "spack install boost+mpi^$mpi", timeout => 12000;
    assert_script_run 'spack load boost';

    record_info 'boost info', script_output 'spack info boost';
    barrier_wait('CLUSTER_PROVISIONED');
    barrier_wait('MPI_SETUP_READY');
    barrier_wait('MPI_BINARIES_READY');
    barrier_wait('MPI_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_run_hook ($self) {
    $self->uninstall_spack_module('boost');
}

sub post_fail_hook ($self) {
    # Upload all the modules.
    # Inside compiled modules comes as <module>-<version>-<hash>
    # Each module includes build logs under <module>-<version>-<hash>/.spack
    my $compiler_ver = script_output("gcc --version | grep -E '\\b[0-9]+\.[0-9]+\.[0-9]+\$' | awk '{print \$4}'");
    my $arch = get_var('ARCH');
    my $node = script_output('hostname');
    $self->tar_and_upload_log("/opt/spack/linux-sle_hpc15-$arch/gcc-$compiler_ver", "/tmp/spack_$node.tar.bz2");
}

1;
