# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that realtime kernel is running
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    # check booted kernel, expected RT
    validate_script_output("uname -v", sub { m/\s{1}PREEMPT\s{1}RT\s{1}/ });
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
    return {fatal => 0};
}


1;
