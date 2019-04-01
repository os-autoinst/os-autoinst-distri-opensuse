# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: run InfiniBand performance tests
#
# Maintainer: Sebastian Chlad <schlad@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use lockapi;
use Utils::Backends 'use_ssh_serial_console';
use ipmi_backend_utils;


our $master;
our $slave;

sub ibtest_slave {
    barrier_wait('IBTEST_BEGIN');
    script_run('ib_write_bw');
    # wait until test is finished
    barrier_wait('IBTEST_DONE');
}

sub ibtest_master {
    my $master = get_required_var('IBTEST_IP1');
    my $slave  = get_required_var('IBTEST_IP2');

    # do all test preparations and setup
    zypper_call('--gpg-auto-import-keys ref');

    barrier_wait('IBTEST_BEGIN');
    assert_script_run("ib_write_bw $slave > /tmp/ib_write_bw.txt", 10);
    upload_logs("/tmp/ib_write_bw.txt");

    barrier_wait('IBTEST_DONE');
    barrier_destroy('IBTEST_SETUP');
    barrier_destroy('IBTEST_BEGIN');
    barrier_destroy('IBTEST_DONE');
}

sub run {
    my $self = shift;
    my $role = get_required_var('IBTEST_ROLE');
    $master = get_required_var('IBTEST_IP1');
    $slave  = get_required_var('IBTEST_IP2');

    $self->select_serial_terminal;

    # test is utilizing perftest
    zypper_call('in perftest');
    # unload firewall. MPI- and libfabric-tests require too many open ports
    script_run("systemctl stop firewalld");
    barrier_wait('IBTEST_SETUP');

    # create and distribute ssh key
    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$master");
    script_run("/usr/bin/clear");
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$slave");
    script_run("/usr/bin/clear");


    if ($role eq 'IBTEST_MASTER') {
        ibtest_master;
    }
    elsif ($role eq 'IBTEST_SLAVE') {
        ibtest_slave;
    }

    power_action('poweroff');
}

sub post_fail_hook {
    my $self = @_;
    my $role = get_required_var('IBTEST_ROLE');
    $self->save_and_upload_log('systemctl list-units -l', '/tmp/systemd_units.log', {screenshot => 0});
}

1;

=head1 bare metal performance testing for InfiniBand

=head2 Overview
This test is executing the perftest tools for checking the IB performance

In order to run this testsuite, two machines with InfiniBand HCA's are required.

=head1 openQA setup

=head2 openQA worker setup
The workers with the InfiniBand HCA's need a special worker class, in this case
we assume it is "64bit-mlx_con5".
=head2 openQA test suites
As the test is executed on two hosts, two test suites should be created:

=head3 ibtest-master	
IBTESTS=IB_perf
IBTEST_IP1=<IP_SUT1>
IBTEST_IP2=<IP_SUT2>
IBTEST_ROLE=IBTEST_MASTER
TEST=ibtest-master
WORKER_CLASS=64bit-mlx_con5

=head3 ibtest-slave	
IBTESTS=IB_perf
IBTEST_IP1=<master IP>
IBTEST_IP2=<slave IP>
IBTEST_ROLE=IBTEST_SLAVE
PARALLEL_WITH=ibtest-master
TEST=ibtest-slave
WORKER_CLASS=64bit-mlx_con5
