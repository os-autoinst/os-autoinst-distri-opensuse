# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic MPI integration test using IMB.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';
use Utils::Logging 'export_logs';
use isotovideo;

use POSIX 'strftime';

sub run ($self) {
    select_serial_terminal();
    my $mpi = get_required_var('MPI');
    my $mpi2load = '';
    my %exports_path = (
        bin => '/home/bernhard/bin',
        hpc_lib => '/usr/lib/hpc',
    );
    my $user_virtio_fixed = isotovideo::get_version() >= 35;
    my $prompt = $user_virtio_fixed ? $testapi::username . '@' . get_required_var('HOSTNAME') . ':~> ' : undef;

    script_run("sudo -u $testapi::username mkdir -p $exports_path{bin}");
    zypper_call("in imb-gnu-$mpi-hpc");

    type_string('pkill -u root', lf => 1) unless $user_virtio_fixed;
    select_user_serial_terminal($prompt);
    # module load for openmpi2,3 and4 uses 'openmpi' without its version
    $mpi2load = ($mpi =~ /openmpi2|openmpi3|openmpi4/) ? 'openmpi' : $mpi;

    $self->check_nodes_availability();

    # And login as normal user to run the tests
    # NOTE: This behaves weird. Need another solution apparently
    type_string('pkill -u root') unless $user_virtio_fixed;
    select_user_serial_terminal($prompt);
    # load mpi after all the relogins
    my @load_modules = $mpi2load;
    assert_script_run("module load gnu @load_modules");
    script_run("module av");

    my $imb_version = script_output("rpm -q --queryformat '%{VERSION}' imb-gnu-$mpi-hpc");
    record_info('testing IMB', 'Run all IMB-MPI1 components');
    # Run IMB-MPI1 without args to run the whole set of testings. Mind the timeout if you do so
    assert_script_run("mpirun -np 4 /usr/lib/hpc/gnu7/$mpi/imb/$imb_version/bin/IMB-MPI1 PingPong");
    barrier_wait('IMB_TEST_DONE');
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
given

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

=item $imb_version
Stores the version of the imb installed package. It is used to determine the
path in the L<lib|/usr/lib/hpc/gnu7/$mpi/imb> which the bins are located.

=cut
