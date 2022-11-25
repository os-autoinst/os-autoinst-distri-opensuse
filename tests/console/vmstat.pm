# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: procps
# Summary: Test procps installation and verify vmstat utility and compare the output with/without load.
# - Install procps
# - Run vmstat with options
# - Run vmstat without load and Read output
# - Run vmstat with load and Read output
# - Compare the output of vmstat with and without load
# Maintainer: QE Core <qe-core@suse.de>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use strict;
use warnings;
use POSIX;
use registration qw(add_suseconnect_product get_addon_fullname is_phub_ready);
use List::Util qw(min);
use console::vmstat_utils;

sub run {
    my ($vm, $cpu);
    select_serial_terminal;

    # Package 'stress-ng' requires PackageHub is available
    return unless is_phub_ready();

    zypper_call('in procps');
    validate_script_output("vmstat",
        qr/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+).*(\s+|\d+)+/s);

    # Extend vmstat utility. Verifying the vmstat report information with options and comparing the output with and without load.
    validate_script_output("vmstat -t",
        qr/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+\s-+timestamp-+).*(\s+|\d+)+/s);
    validate_script_output("vmstat -a",
        qr/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+).*(\s+.*\s+inact\s+active\s*.*).*(\s+|\d+)+/s);
    validate_script_output("vmstat -f", qr/(\d+\s+forks)/s);

    # Running vmstat under light load and dumping the output to a file. Calculate and collect the minimum idle memory from the output.
    assert_script_run("sync; echo 3 > /proc/sys/vm/drop_caches");
    assert_script_run("vmstat 2 10 > /tmp/output_light.log");
    assert_script_run("cat /tmp/output_light.log");
    my ($mem_lite_load_ref, $cpu_lite_load_ref) = read_memory_cpu("/tmp/output_light.log");
    my @mem_lite_load = @$mem_lite_load_ref;
    my @cpu_lite_load = @$cpu_lite_load_ref;
    my $min_mem_lightload = min(@mem_lite_load);
    my $min_cpu_lightload = min(@cpu_lite_load);

    # Increasing the load in the system using package stress-ng.
    zypper_call('in stress-ng');
    my $total_cpu = script_output("cat /proc/cpuinfo | grep processor | wc -l");
    my $total_mem = script_output("free -h | awk '/Mem\:/ { print \$2 }'");
    if ($total_cpu == 1) { $cpu = $total_cpu } else { $cpu = floor($total_cpu * 0.75) }
    $vm = 50;
    my $stressng_pkg = "nohup stress-ng --cpu $cpu --vm $vm --vm-bytes 256m --timeout 60s&";
    enter_cmd "$stressng_pkg";
    sleep 10;

    # Running vmstat during the high load and storing the result in file. calculate the average of idle memory
    assert_script_run("vmstat 2 10 > /tmp/output_load.log");
    assert_script_run("cat /tmp/output_load.log");

    # kill the running background process stress-ng.
    assert_script_run("killall stress-ng");

    my ($mem_hvy_ref, $cpu_hvy_ref) = read_memory_cpu("/tmp/output_load.log");
    my @mem_hvy = @$mem_hvy_ref;
    my @cpu_hvy = @$cpu_hvy_ref;
    my $avg_mem_heavyload = average(@mem_hvy);
    my $avg_cpu_heavyload = average(@cpu_hvy);

    # Comparison  of the vmstat with and without load
    if ($avg_mem_heavyload > $min_mem_lightload or $avg_cpu_heavyload < $min_cpu_lightload) {
        my $error_msg = "Expected condition is $avg_mem_heavyload < $min_mem_lightload and $avg_cpu_heavyload > $min_cpu_lightload";
        die($error_msg);
    }
}

1;
