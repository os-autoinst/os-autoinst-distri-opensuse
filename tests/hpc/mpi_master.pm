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
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';
use Utils::Logging 'export_logs';
use hpc::formatter;
use isotovideo;

use POSIX 'strftime';

sub run ($self) {
    select_serial_terminal();
    my $mpi = $self->get_mpi();
    my ($mpi_compiler, $mpi_c) = $self->get_mpi_src();
    my $mpi_bin = 'mpi_bin';
    my $mpi2load = '';
    my @cluster_nodes = $self->cluster_names();
    my $cluster_nodes = join(',', @cluster_nodes);
    my %exports_path = (
        bin => '/home/bernhard/bin',
        hpc_lib => '/usr/lib/hpc',
    );
    my $user_virtio_fixed = isotovideo::get_version() >= 35;
    my $prompt = $user_virtio_fixed ? $testapi::username . '@' . get_required_var('HOSTNAME') . ':~> ' : undef;

    script_run("sudo -u $testapi::username mkdir -p $exports_path{bin}");
    zypper_call("in $mpi-gnu-hpc $mpi-gnu-hpc-devel imb-gnu-$mpi-hpc");

    my $need_restart = $self->setup_scientific_module();
    $self->relogin_root if $need_restart;
    $self->setup_nfs_server(\%exports_path);

    type_string('pkill -u root', lf => 1) unless $user_virtio_fixed;
    select_user_serial_terminal($prompt);
    # for <15-SP2 the openmpi2 module is named simply openmpi
    $mpi2load = ($mpi =~ /openmpi2|openmpi3|openmpi4/) ? 'openmpi' : $mpi;

    barrier_wait('CLUSTER_PROVISIONED');
    record_info 'CLUSTER_PROVISIONED', strftime("\%H:\%M:\%S", localtime);
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
    record_info 'NFS', 'setup NFS';
    select_console('root-console');
    systemctl 'restart nfs-server';
    # And login as normal user to run the tests
    # NOTE: This behaves weird. Need another solution apparently
    type_string('pkill -u root') unless $user_virtio_fixed;
    select_user_serial_terminal($prompt);
    # load mpi after all the relogins
    my @load_modules = $mpi2load;
    push @load_modules, 'python3-scipy' if check_var('HPC_LIB', 'scipy');
    push @load_modules, 'papi' if check_var('HPC_LIB', 'papi');
    push @load_modules, 'openblas' if check_var('HPC_LIB', 'openblas');
    assert_script_run "module load gnu @load_modules";
    script_run "module av";

    barrier_wait('MPI_SETUP_READY');
    record_info 'MPI_SETUP_READY', strftime("\%H:\%M:\%S", localtime);
    if (get_var('HPC_LIB') eq 'papi') {
        my $papi_version = script_output("module whatis papi | grep Version");
        $papi_version = (split(/: /, $papi_version))[2];
        assert_script_run("$mpi_compiler $exports_path{'bin'}/$mpi_c -o $exports_path{'bin'}/$mpi_bin -I/usr/lib/hpc/papi/$papi_version/include/ -L/usr/lib/hpc/papi/$papi_version/lib64/ -lpapi") if $mpi_compiler;
    } elsif (get_var('HPC_LIB') eq 'openblas') {
        my $version = script_output("module whatis openblas | grep Version");
        $version = (split(/: /, $version))[2];
        assert_script_run("$mpi_compiler -o $exports_path{'bin'}/$mpi_bin $exports_path{'bin'}/$mpi_c -Iexports_path{'hpc'}/gnu7/openblas/$version/include -Iexports_path{'hpc'}/gnu7/openblas/$version/lib64 -lopenblas");
    } else {
        assert_script_run("$mpi_compiler $exports_path{'bin'}/$mpi_c -o $exports_path{'bin'}/$mpi_bin") if $mpi_compiler;
    }

    # python code is not compiled. *mpi_bin* is expected as a compiled binary. if compilation was not
    # invoked return source code (ex: sample_scipy.py).
    $mpi_bin = ($mpi_compiler) ? $mpi_bin : $mpi_c;
    barrier_wait('MPI_BINARIES_READY');
    record_info 'MPI_BINARIES_READY', strftime("\%H:\%M:\%S", localtime);
    my $mpirun_s = hpc::formatter->new();

    unless ($mpi_c eq 'sample_cplusplus.cpp') {    # because calls expects minimum 2 nodes
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
            ##TODO: consider more robust handling of various errors
            die("echo $return - not expected errorcode");
        }
    } else {
        if ($mpi_c eq 'sample_cplusplus.cpp') {
            assert_script_run($mpirun_s->slave_nodes("$exports_path{'bin'}/$mpi_bin"), timeout => 120);
            assert_script_run($mpirun_s->n_nodes("$exports_path{'bin'}/$mpi_bin", 2), timeout => 120);
        } else {
            # Skipping papi test on compute nodes as for some reason
            # module is not getting loaded for the c test execution
            unless (get_var('HPC_LIB') eq 'papi') {
                assert_script_run($mpirun_s->all_nodes("$exports_path{'bin'}/$mpi_bin"), timeout => 120);
            }
        }
    }
    barrier_wait('MPI_RUN_TEST');
    record_info 'MPI_RUN_TEST', strftime("\%H:\%M:\%S", localtime);

    my $imb_version = script_output("rpm -q --queryformat '%{VERSION}' imb-gnu-$mpi-hpc");

    if ($mpi eq 'mvapich2') {
        my $return = script_run("set -o pipefail; mpirun -np 4 /usr/lib/hpc/gnu7/$mpi/imb/$imb_version/bin/IMB-MPI1 PingPong |& tee /tmp/mpi_bin.log", timeout => 120);
        if ($return == 136) {
            if (script_run('grep \'Caught error: Floating point exception (signal 8)\' /tmp/mpi_bin.log') == 0) {
                record_soft_failure('bsc#1175679 Floating point exception should be fixed on mvapich2/2.3.4');
            }
        } elsif ($return == 1 || $return == 139 || $return == 255) {
            if (script_run('grep \'Caught error: Segmentation fault (signal 11)\' /tmp/mpi_bin.log') == 0) {
                record_soft_failure('bsc#1144000 MVAPICH2: segfault while executing without ib_uverbs loaded');
            }
        } elsif (script_run('grep \'failure occurred while posting a receive for message data\' /tmp/mpi_bin.log') == 0) {
            record_soft_failure('bsc#1209130 MPI Benchmarks unable to run on 15SP1 with imb-gnu-mvapich2-hpc');
        } else {
            ##TODO: consider more robust handling of various errors
            die("echo $return - not expected errorcode") unless $return == 0;
        }
    } else {
        record_info 'testing IMB', 'Run all IMB-MPI1 components';
        # Run IMB-MPI1 without args to run the whole set of testings. Mind the timeout if you do so
        assert_script_run("mpirun -np 4 /usr/lib/hpc/gnu7/$mpi/imb/$imb_version/bin/IMB-MPI1 PingPong");
    }
    barrier_wait('IMB_TEST_DONE');
    record_info 'IMB_TEST_DONE', strftime("\%H:\%M:\%S", localtime);
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    export_logs();
}

1;

=head1 Variables explanation

=over
=item $mpi
Stores the MPI implementation. This is usually whatever MPI job variable is
given. It is changed when openmpi is used to get the corresponding version
for products despite the MPI value. C<get_mpi> function needs to get improved

=item $mpi_compiler
This is determined based on the source code which is used and comes together
with C<mpi_c>

=item $mpi_c
The source code to compile and run. The source codes are located in
 L<data|data/hpc>

=item $mpi_bin
Holds the name of the compiled source code

=item $cluster_nodes
A str representation of all the nodes of the cluster, including master node.

=item %exports_path
Holds the common paths which nodes locate libraries and source code.

=item $user_virtio_fixed
A boolean which determines whether isotovideo can set user console prompt or
not

=item $prompt
Used by C<select_user_serial_terminal> to get a user terminal

=item $mpi2load
differentiates the openmpi name to be used in lmod loading. C<lmod> can load
only one mpi. In case of openmpi2, openmpi3, openmpi4 which is stored in C<mpi>,
it takes their place as all are found as I<openmpi>

=item $hostname
It just holds the I<hostname> to avoid recall C<get_var> again and again

=item $mpirun_s
Holds an object which implements wrappers for B<mpirun>. Implementation can be
found at L<formatter|lib/hpc/formatter.pm>

=item $imb_version
Stores the version of the imb installed package. It is used to determine the
path in the L<lib|/usr/lib/hpc/gnu7/$mpi/imb> which the bins are located.

=back

=head1 Notes to keep in mind

=head2 Known Bugs

C<mvapich2> in SLE15SP2 and below suffers from various issues which causes
segmentation faults and Floating point exception. Those should be handled
with C<record_soft_failure>

=head2 Other Notes

- B<papi> and B<OpenBLAS> modules and their code samples do not
use OpenMP, and as such are running at a single node.

=head2 Settings
TODO

=cut
