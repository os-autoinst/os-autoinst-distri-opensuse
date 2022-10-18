# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that realtime kernel is running
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    select_serial_terminal;
    # check booted kernel, expected RT
    validate_script_output("uname -v", sub { m/\s{1}PREEMPT(\s{1}|_)RT\s{1}/ });
    # display running RT processes, expected to see FF - SCHED_FIFO or RR - SCHED_RR processes
    validate_script_output("ps -e -o pid,start_time,pri,cls,command", sub { m/FF|RR/ });
    # is realtime ?
    validate_script_output("cat /sys/kernel/realtime", sub { m/1/ });
    # check kernel in procfs
    validate_script_output("cat /proc/sys/kernel/osrelease", sub { m/rt/ });
    # period over which real-time task bandwidth enforcement is measured
    # The default value is 1000000 µs
    validate_script_output("cat /proc/sys/kernel/sched_rt_period_us", sub { m/1000000/ });
    # Quantum allocated to real-time tasks during sched_rt_period_us. Setting to -1 disables RT bandwidth enforcement.
    # By default, RT tasks may consume 95%CPU/sec, thus leaving 5%CPU/sec or 0.05s to be used by SCHED_OTHER tasks.
    # The default value is 950000 µs
    validate_script_output("cat /proc/sys/kernel/sched_rt_runtime_us", sub { m/950000/ });
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';

    $self->export_logs_basic;
    $self->upload_coredumps;
}


1;
