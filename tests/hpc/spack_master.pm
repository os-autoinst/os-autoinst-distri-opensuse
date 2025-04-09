# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: HPC_Module: Test Spack package installation and features
#
# Acts as the master node of the cluster to execute parallel executions
# The flow is impacted by HPC_LIB job variable. When is ommitted it will
# use simple_mpi.c. if the value is boost C<sample_boost.cpp> will be used.
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use Utils::Logging qw(tar_and_upload_log export_logs);
use version_utils 'is_sle';

our $file = 'tmpresults.xml';
# xml vars
my $load_rt = undef;
my $compile_rt = undef;
my $rt = undef;

sub run ($self) {
    my $mpi = get_required_var('MPI');
    my ($mpi_compiler, $mpi_c) = $self->get_mpi_src();
    my $mpi_bin = 'mpi_bin';
    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);
    my %exports_path = (bin => '/home/bernhard/bin');
    $self->setup_nfs_server(\%exports_path);
    $self->prepare_spack_env($mpi);

    record_info 'spack info', script_output "spack info $mpi";
    barrier_wait('CLUSTER_PROVISIONED');

    ## all nodes should be able to ssh to each other, as MPIs requires so
    $self->generate_and_distribute_ssh($testapi::username);
    $self->check_nodes_availability();
    record_info('INFO', script_output('cat /proc/cpuinfo'));

    my $hostname = get_var('HOSTNAME', 'susetest');
    record_info "hostname", "$hostname";
    assert_script_run "hostnamectl status|grep $hostname";

    assert_script_run("wget --quiet " . data_url("hpc/$mpi_c") . " -O $exports_path{'bin'}/$mpi_c");

    barrier_wait('MPI_SETUP_READY');
    if (check_var('HPC_LIB', 'boost')) {
        $load_rt = assert_script_run "spack load boost^$mpi";
        assert_script_run 'spack find --loaded';
        $compile_rt = assert_script_run("$mpi_compiler $exports_path{'bin'}/$mpi_c -o $exports_path{'bin'}/$mpi_bin -l boost_mpi -I \${BOOST_ROOT}/include/ -L \${BOOST_ROOT}/lib 2>&1 > /tmp/make.out");
    } else {
        $load_rt = assert_script_run "spack load $mpi";
        $compile_rt = assert_script_run("$mpi_compiler $exports_path{'bin'}/$mpi_c -o $exports_path{'bin'}/$mpi_bin  2>&1 > /tmp/make.out");
    }
    test_case('Enable modules', 'Load spack modules', $load_rt);
    test_case('Compilation', 'Program compiled successfully', $compile_rt);
    barrier_wait('MPI_BINARIES_READY');

    # Testing compiled code
    record_info('INFO', 'Run MPI over single machine');
    # Define library path for mpich on 15-SP3
    my $ld_library_path;
    $ld_library_path = 'LD_LIBRARY_PATH=/usr/lib64/mpi/gcc/mpich/lib64' if is_sle('=15-SP3');
    $rt = assert_script_run("${ld_library_path} mpirun $exports_path{'bin'}/$mpi_bin");
    test_case("$mpi_compiler test 0", 'Run in a single node', $compile_rt);

    record_info('INFO', 'Run MPI over several nodes');
    my $nodes = join(',', @cluster_nodes);
    $rt = assert_script_run("$ld_library_path mpirun -n 2 --host $nodes $exports_path{'bin'}/$mpi_bin", timeout => 240);
    test_case("$mpi_compiler test 0", 'Run parallel', $compile_rt);

    barrier_wait('MPI_RUN_TEST');
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_run_hook ($self) {
    tar_and_upload_log("/etc/spack", "/tmp/spack_etc.tar", {timeout => 1200, screenshot => 1});
    $self->uninstall_spack_modules();
    parse_test_results('HPC MPI tests', $file, @all_tests_results);
    parse_extra_log('XUnit', "/tmp/$file");
}

sub post_fail_hook ($self) {
    # Upload all the modules.
    # Inside compiled modules comes as <module>-<version>-<hash>
    # Each module includes build logs under <module>-<version>-<hash>/.spack
    my $compiler_ver = script_output("gcc --version | grep -E '\\b[0-9]+\.[0-9]+\.[0-9]+\$' | awk '{print \$4}'");
    my $arch = get_var('ARCH');
    my $node = script_output('hostname');
    tar_and_upload_log("/opt/spack/linux-sle_hpc15-$arch/gcc-$compiler_ver", "/tmp/spack_$node.tar.bz2", timeout => 360);
    upload_logs('/tmp/make.out');
    export_logs();
}

1;
