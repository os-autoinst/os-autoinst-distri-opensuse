# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: run InfiniBand test suite hpc-testing
#
# Maintainer: Michael Moese <mmoese@suse.de>, Nick Singer <nsinger@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use lockapi;
use ipmi_backend_utils;
use version_utils 'is_sle';


our $master;
our $slave;


sub upload_ibtest_logs {
    my $self = @_;
    my $role = get_required_var('IBTEST_ROLE');

    if ($role eq 'IBTEST_MASTER') {
        # remove non-printable characters
        script_run('tr -cd \'\11\12\15\40-\176\' < results/TEST-ib-test.xml > /tmp/results.xml');
        parse_extra_log('XUnit', '/tmp/results.xml');
    }
    $self->save_and_upload_log('dmesg',                   '/tmp/dmesg.log',         {screenshot => 0});
    $self->save_and_upload_log('systemctl list-units -l', '/tmp/systemd_units.log', {screenshot => 0});
}

sub ibtest_slave {
    zypper_call('in iputils python');
    barrier_wait('IBTEST_BEGIN');
    # wait until test is finished
    barrier_wait('IBTEST_DONE');
}

sub ibtest_master {
    my $master             = get_required_var('IBTEST_IP1');
    my $slave              = get_required_var('IBTEST_IP2');
    my $hpc_testing        = get_var('IBTEST_GITTREE', 'https://github.com/SUSE/hpc-testing.git');
    my $hpc_testing_branch = get_var('IBTEST_GITBRANCH', 'master');
    my $timeout            = get_var('IBTEST_TIMEOUT', '3600');

    # construct some parameters to allow to customize test runs when needed
    my $start_phase  = get_var('IBTEST_START_PHASE');
    my $end_phase    = get_var('IBTEST_END_PHASE');
    my $phase        = get_var('IBTEST_ONLY_PHASE');
    my $mpi_flavours = get_var('IBTEST_MPI_FLAVOURS');
    my $ipoib_modes  = get_var('IBTEST_IPOIB_MODES');

    my $args = '';

    $args = '-v '               if get_var('IBTEST_VERBOSE');
    $args = $args . '--in-vm '  if get_var('IBTEST_IN_VM');
    $args = $args . '--no-mad ' if get_var('IBTEST_NO_MAD');

    if ($phase != '') {
        $args = $args . "--phase $phase";
    } else {
        $args = $args - "--start-phase $start_phase " if $start_phase;
        $args = $args - "--end-phase $end_phase "     if $end_phase;
    }

    $args = $args . "--mpi $mpi_flavours "  if $mpi_flavours;
    $args = $args . "--ipoib $ipoib_modes " if $ipoib_modes;

    # do all test preparations and setup
    zypper_ar(get_required_var('DEVEL_TOOLS_REPO'), no_gpg_check => 1);
    zypper_call('in git-core twopence bc iputils python');

    # create symlinks, the package is (for now) broken
    assert_script_run('ln -sf /usr/lib64/libtwopence.so.0.3.8 /usr/lib64/libtwopence.so.0');
    # pull in the testsuite
    assert_script_run("git -c http.sslVerify=false clone $hpc_testing --branch $hpc_testing_branch");

    # wait until the two machines under test are ready setting up their local things
    assert_script_run('cd hpc-testing');
    barrier_wait('IBTEST_BEGIN');
    assert_script_run("./ib-test.sh $args $master $slave", $timeout);

    barrier_wait('IBTEST_DONE');
    barrier_destroy('IBTEST_SETUP');
    barrier_destroy('IBTEST_BEGIN');
    barrier_destroy('IBTEST_DONE');
}

sub run {
    my $self        = shift;
    my $role        = get_required_var('IBTEST_ROLE');
    my $version     = get_required_var("VERSION");
    my $arch        = get_required_var("ARCH");
    my $sdk_version = get_required_var("BUILD_SDK");

    $master = get_required_var('IBTEST_IP1');
    $slave  = get_required_var('IBTEST_IP2');

    $self->select_serial_terminal;

    # unload firewall. MPI- and libfabric-tests require too many open ports
    systemctl("stop " . opensusebasetest::firewall);

    # create a ssh key if we don't have one
    script_run('[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -b 2048 -t rsa -q -N "" -f /root/.ssh/id_rsa');
    # distribute the ssh key to the machines
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$master");
    script_run("/usr/bin/clear");
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$slave");
    script_run("/usr/bin/clear");

    if ((is_sle && is_sle('>15-sp2')) && (script_run('zypper se mpitests-openmpi3') != 0)) {
        record_info('mpistests-openmpi3', 'add GA Repo (mpitests-openmpi3 missing)', result => 'softfail');
        zypper_ar("http://download.suse.de/ibs/SUSE:/SLE-$version:/GA/standard/SUSE:SLE-$version:GA.repo");
    }

    barrier_wait('IBTEST_SETUP');

    if ($role eq 'IBTEST_MASTER') {
        ibtest_master;
    }
    elsif ($role eq 'IBTEST_SLAVE') {
        ibtest_slave;
    }

    upload_ibtest_logs;

    power_action('poweroff');
}

sub post_fail_hook {
    my $self = shift;
    upload_ibtest_logs;
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

