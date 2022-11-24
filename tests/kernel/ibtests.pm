# SUSE's openQA tests
#
# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: git-core twopence-shell-client bc iputils python
# Summary: run InfiniBand test suite hpc-testing
#
# Maintainer: Michael Moese <mmoese@suse.de>, Nick Singer <nsinger@suse.de>, ybonatakis <ybonatakis@suse.com>

use Mojo::Base qw(opensusebasetest);
use Utils::Backends;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use lockapi;
use mmapi;
use Utils::Logging qw(save_and_upload_log save_and_upload_systemd_unit_log);

our $master;
our $slave;

sub upload_ibtest_logs {
    my $self = shift;

    save_and_upload_log('dmesg', '/tmp/dmesg.log', {screenshot => 0});
    save_and_upload_log('systemctl list-units -l', '/tmp/systemd_units.log', {screenshot => 0});

    save_and_upload_systemd_unit_log('opensm.service');
    save_and_upload_systemd_unit_log('srp_daemon.service');
    save_and_upload_systemd_unit_log('nvmet.service');
    save_and_upload_systemd_unit_log('nvmf-autoconnect.service');
    save_and_upload_systemd_unit_log('rdma-hw.service');
    save_and_upload_systemd_unit_log('rdma-load-modules@infiniband.service');
    save_and_upload_systemd_unit_log('rdma-load-modules@rdma.service');
    save_and_upload_systemd_unit_log('rdma-load-modules@roce.service');
    save_and_upload_systemd_unit_log('rdma-ndd.service');
    save_and_upload_systemd_unit_log('rdma-sriov.service');
}

sub ibtest_slave {
    my $self = shift;
    barrier_wait('IBTEST_BEGIN');
    barrier_wait('IBTEST_DONE');
    $self->upload_ibtest_logs;
}

sub ibtest_master {
    my $self = shift;
    my $master = get_required_var('IBTEST_IP1');
    my $slave = get_required_var('IBTEST_IP2');
    my $hpc_testing = get_var('IBTEST_GITTREE', 'https://github.com/SUSE/hpc-testing.git');
    my $hpc_testing_branch = get_var('IBTEST_GITBRANCH', 'master');
    my $timeout = get_var('IBTEST_TIMEOUT', '3600');

    # construct some parameters to allow to customize test runs when needed
    my $start_phase = get_var('IBTEST_START_PHASE');
    my $end_phase = get_var('IBTEST_END_PHASE');
    my $phase = get_var('IBTEST_ONLY_PHASE');
    my $mpi_flavours = get_var('IBTEST_MPI_FLAVOURS');
    my $ipoib_modes = get_var('IBTEST_IPOIB_MODES');

    my $args = '';

    $args = '-v ' if get_var('IBTEST_VERBOSE');
    $args = $args . '--in-vm ' if get_var('IBTEST_IN_VM');
    $args = $args . '--no-mad ' if get_var('IBTEST_NO_MAD');

    if ($phase ne '') {
        $args = $args . "--phase $phase ";
    } else {
        $args = $args . "--start-phase $start_phase " if $start_phase;
        $args = $args . "--end-phase $end_phase " if $end_phase;
    }

    $args = $args . "--mpi $mpi_flavours " if $mpi_flavours;
    $args = $args . "--ipoib $ipoib_modes " if $ipoib_modes;


    # pull in the testsuite
    assert_script_run("git clone $hpc_testing --branch $hpc_testing_branch", timeout => $timeout);

    # wait until the two machines under test are ready setting up their local things
    assert_script_run('cd hpc-testing');
    barrier_wait('IBTEST_BEGIN');
    script_run("./ib-test.sh $args $master $slave", timeout => $timeout);
    script_run('tr -cd \'\11\12\15\40-\176\' < results/TEST-ib-test.xml > /tmp/results.xml');
    parse_extra_log('XUnit', '/tmp/results.xml');

    barrier_wait('IBTEST_DONE');
    $self->upload_ibtest_logs;

    barrier_destroy('IBTEST_SETUP');
    barrier_destroy('IBTEST_BEGIN');
    barrier_destroy('IBTEST_DONE');
}

sub run {
    my $self = shift;
    my $role = get_required_var('IBTEST_ROLE');

    $master = get_required_var('IBTEST_IP1');
    $slave = get_required_var('IBTEST_IP2');

    select_serial_terminal;

    # wait for both machines to boot up before we continue
    barrier_wait('IBTEST_SETUP');

    # distribute the ssh key to the machines
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$master");
    script_run("/usr/bin/clear");
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$slave");
    script_run("/usr/bin/clear");

    if ($role eq 'IBTEST_MASTER') {
        $self->ibtest_master;
    }
    elsif ($role eq 'IBTEST_SLAVE') {
        $self->ibtest_slave;
    }

    power_action('poweroff');
}

sub post_fail_hook {
    my $self = shift;
    my $role = get_required_var('IBTEST_ROLE');

    if ($role eq 'IBTEST_MASTER') {
        script_run('tr -cd \'\11\12\15\40-\176\' < results/TEST-ib-test.xml > /tmp/results.xml');
        parse_extra_log('XUnit', '/tmp/results.xml');
    }

    $self->upload_ibtest_logs;
    $self->SUPER::post_fail_hook;
}

1;

=head1 bare metal testing for InfiniBand
This section describes how to setup your environment for running the testsuite on bare metal.
Once fully implemented, it will be expanded to virtualized testing.

=head2 Overview
This test is executing the hpc-testing testsuite from https://github.com/SUSE/hpc-testing

In order to run this testsuite, two machines with InfiniBand HCA's are required.

The test has some additional dependencies (twopence) that need to be in DEVEL_TOOLS_REPO.

=head1 openQA setup

=head2 openQA worker setup
The workers with the InfiniBand HCA's need a special worker class, in this case
we assume it is "64bit-mlx_con5". See the schedule/kernel/ibtest-master.yaml and
schedule/kernel/ibtest-slave.yaml for more details.

=head2 openQA test suites
As the test is executed on two hosts, two test suites should be created. Please note:
most settings are now defined in the YAML schedule.

=head3 ibtest-master
YAML_SCHEDULE=schedule/kernel/ibtest-master.yaml

=head3 ibtest-slave
PARALLEL_WITH=ibtest-master
YAML_SCHEDULE=schedule/kernel/ibtest-slave.yaml

=head3 additional configuration variables
These are only effective, when defined for the master job. Leave them at their
defaults unless you know what you are doing.

IBTEST_TIMEOUT
 Test timeout in seconds.
 Default: 3600 (1 hour)
IBTEST_ONLY_PHASE
 integer value. Only run the defined phase.
 Not set by default.
IBTEST_START_PHASE
 integer value. Start with specified phase.
 Default: 0
IBTEST_END_PHASE
 integer value. End with specified phase.
 Default: 999
IBTEST_MPI_FLAVOURS
 Comma separated list of MPI flavours to test.
 Default: mvapich2,mpich,openmpi,openmpi2,openmpi3
IBTEST_IPOIB_MODES
 Comma separated list of IPoIB modes to test
 Default: connected,datagram
IBTEST_VERBOSE
 Set this variable to enable verbose mode
 Default: not set
IBTEST_IN_VM
 Set this variable to enable testing in a VM.
 Default: not set
IBTEST_NO_MAD
 Set this variable toisable test that requires MAD support. Needed for testing over SR-IOV
 Default: not set

