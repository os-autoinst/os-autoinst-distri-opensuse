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
use Utils::Architectures;
use version_utils 'is_sle';

sub run ($self) {
    my $mpi = $self->get_mpi();
    my $exports_path = '/home/bernhard/bin';
    set_var('SPACK', '1');
    zypper_call "in spack";
    $self->relogin_root;
    #$self->prepare_spack_env($mpi);
    my @hpc_deps = ('libucp0');
    if (is_sle('>=15-SP3')) {
        push @hpc_deps, 'libhwloc15' if $mpi =~ m/mpich/;
        push @hpc_deps, ('libfabric1', 'libpsm2') if $mpi =~ m/openmpi/;
        pop @hpc_deps if (is_aarch64 && $mpi =~ m/openmpi/);
    } else {
        push @hpc_deps, 'libpciaccess0' if $mpi =~ m/mpich/;
        push @hpc_deps, 'libfabric1' if $mpi =~ m/openmpi/;
    }
    push @hpc_deps, ('libibmad5') if $mpi =~ m/mvapich2/;
    zypper_call("in @hpc_deps");

    barrier_wait('CLUSTER_PROVISIONED');
    barrier_wait('MPI_SETUP_READY');

    $self->mount_nfs_exports($exports_path);
    assert_script_run "source /usr/share/spack/setup-env.sh";
    # Once the /opt/spack is mounted `boost` should be available
    script_run "module av";
    record_info 'boost info', script_output 'spack info boost';
    barrier_wait('MPI_BINARIES_READY');
    barrier_wait('MPI_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_run_hook ($self) { }

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
