# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: HPC_Module: Test Spack package installation and features
#
# Acts as the master node of the cluster to execute parallel executions
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use utils;
use lockapi;

sub run ($self) {
    my $mpi = $self->get_mpi();
    my ($mpi_compiler, $mpi_c) = $self->get_mpi_src();
    my $mpi_bin = 'mpi_bin';
    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);
    $self->prepare_spack_env($mpi);
    my %exports_path = (
        bin => '/home/bernhard/bin',
        spack => '/home/bernhard/spack',
        hpc_lib => '/usr/lib/hpc',
        spack_lib => '/opt/spack'
    );

    record_info 'boost info', script_output 'spack info boost';
    barrier_wait('CLUSTER_PROVISIONED');
    script_run "pkill -u $testapi::username";
    select_console('root-console');
    $self->setup_nfs_server(\%exports_path);

    # And login as normal user to run the tests
    type_string('pkill -u root');
    $self->select_serial_terminal(0);

    ## all nodes should be able to ssh to each other, as MPIs requires so
    $self->generate_and_distribute_ssh($testapi::username);
    $self->check_nodes_availability();
    record_info('INFO', script_output('cat /proc/cpuinfo'));

    my $hostname = get_var('HOSTNAME', 'susetest');
    record_info "hostname", "$hostname";
    assert_script_run "hostnamectl status|grep $hostname";

    assert_script_run("wget --quiet " . data_url("hpc/$mpi_c") . " -O $exports_path{'bin'}/$mpi_c");

    barrier_wait('MPI_SETUP_READY');

    assert_script_run("$mpi_compiler $exports_path{'bin'}/$mpi_c -o $exports_path{'bin'}/$mpi_bin -l boost_mpi -I \${BOOST_ROOT}/include/ -L \${BOOST_ROOT}/lib 2>&1 > /tmp/make.out");
    barrier_wait('MPI_BINARIES_READY');

    type_string "sudo systemctl restart sshd\n";
    sleep 3;
    type_string("$testapi::password\n");
    record_info('ssh', 'check sshd service before continue');
    systemctl 'status sshd';
    # Testing compiled code
    record_info('INFO', 'Run MPI over single machine');
    assert_script_run("mpirun $exports_path{'bin'}/$mpi_bin");

    record_info('INFO', 'Run MPI over several nodes');
    my $nodes = join(',', @cluster_nodes);
    assert_script_run("mpirun -n 2 --host $nodes $exports_path{'bin'}/$mpi_bin", timeout => 120);
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
    $self->tar_and_upload_log("/opt/spack/linux-sle_hpc15-$arch/gcc-$compiler_ver", "/tmp/spack_$node.tar.bz2", timeout => 360);
    upload_logs('/tmp/make.out');
    $self->export_logs();
}

1;
