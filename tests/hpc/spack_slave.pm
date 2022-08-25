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
    my %exports_path = (
        bin => '/home/bernhard/bin',
        spack => '/home/bernhard/spack',
        hpc_lib => '/usr/lib/hpc',
        spack_lib => '/opt/spack');
    zypper_call "in spack";
    $self->relogin_root;
    my @hpc_deps = $self->get_compute_nodes_deps($mpi);
    zypper_call("in @hpc_deps");

    barrier_wait('CLUSTER_PROVISIONED');
    barrier_wait('MPI_SETUP_READY');
    $self->mount_nfs_exports(\%exports_path);
    type_string('pkill -u root');
    $self->select_serial_terminal(0);

    assert_script_run "source /usr/share/spack/setup-env.sh";
    # Once the /opt/spack is mounted `boost` should be available
    record_info 'boost info', script_output 'spack info boost';
    assert_script_run 'spack load boost';
    script_run "module av";

    ## TODO: Restart only when is needed, otherwise include a softfail
    record_info('ssh restart', 'Ensure sshd service is running before mpirun');
    type_string "sudo systemctl restart sshd\n";
    sleep 3;
    type_string("$testapi::password\n");
    record_info('ssh check', 'Validate sshd service status before mpirun');
    systemctl 'status sshd';
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
