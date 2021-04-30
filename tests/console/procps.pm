# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: procps
# Summary: Test procps installation and verify that its tools work as exepected.
# Extend package vmstat and compare the output with/without load.
# - Install procps
# - Run free and check
# - Run pgrep 1 and check
# - Run pmap 1 and check
# - Run pwdx 1 and check
# - Run vmstat and check
# - Run w and check
# - Run sysctl kernel.random and check
# - Run ps -p 1 and check
# - Run top -b -n 1 and check
# - Run vmstat with options
# - Run vmstat without load and Read output
# - Run vmstat with load and Read output
# - Compare the output of vmstat with and without load
# Maintainer: Paolo Stivanin <pstivanin@suse.com>, Deepthi Yadabettu Venkatachala <deepthi.venkatachala@suse.com>

use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;
use POSIX;
use version_utils;
use registration qw(add_suseconnect_product get_addon_fullname);


use List::Util qw(min);
use console::procps_utils;

sub run {

    my ($self) = @_;
    my ($vm, $cpu);
    $self->select_serial_terminal;
    zypper_call('in procps');
    assert_script_run("rpm -q procps");
    validate_script_output("free",    sub { m/total\s+used\s+free.*\nMem:\s+\d+\s+\d+\s+\d+.*(\n.*)+/ });
    validate_script_output("pgrep 1", sub { m/\d+/ });
    validate_script_output("pmap 1",  sub { m/1:\s+(.*systemd|init)/ });
    validate_script_output("pwdx 1",  sub { m/1:\s+\// });
    validate_script_output("vmstat",
        qr/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+).*(\s+|\d+)+/s);
    validate_script_output("w",
        qr/\d+:\d+:\d+\sup\s+(\d+|:)+(\s\w+|),\s+\d\s\w+,\s+load average:.*USER\s+TTY\s+FROM\s+LOGIN@\s+IDLE\s+JCPU\s+PCPU\s+WHAT.*\w+/s);
    validate_script_output("sysctl kernel.random", sub { m/kernel\.random\.\w+\s=\s((\d+|\w+)|-)+/ });
    validate_script_output("ps -p 1",
        qr/PID\sTTY\s+TIME\sCMD\s+1\s\?\s+\d+:\d+:\d+\s(systemd|init)/);
    validate_script_output("top -b -n 1",
qr/top - \d+:\d+:\d+ up\s+((\d+:\d+)|(\d+ \w+)|(\d+ \w+,\s+\d+:\d+)),\s+\d+ \w+,\s+load average: \d+.\d+, \d+.\d+, \d+.\d+\s+Tasks:\s+\d+\s+total,\s+\d+\s+running,\s+\d+\s+sleeping.*top/s);

    # Extend vmstat utility. Verifying the vmstat with options.
    validate_script_output("vmstat -t",
        qr/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+\s-+timestamp-+).*(\s+|\d+)+/s);
    validate_script_output("vmstat -a",
        qr/(procs\s-+memory-+\s-+swap-+\s-+io-+\s-+system-+\s-+cpu-+).*(\s+.*\s+inact\s+active\s*.*).*(\s+|\d+)+/s);
    validate_script_output("vmstat -f", qr/(\d+\s+forks)/s);

    #Running vmstat under light load and dumping the output to a file. Calculate and collect the minimum idle memory from the output.
    assert_script_run("vmstat 2 10 > /tmp/output_light.log");
    assert_script_run("cat /tmp/output_light.log");
    my ($mem_lite_load_ref, $cpu_lite_load_ref) = read_memory_cpu("/tmp/output_light.log");
    my @mem_lite_load     = @$mem_lite_load_ref;
    my @cpu_lite_load     = @$cpu_lite_load_ref;
    my $min_mem_lightload = min(@mem_lite_load);
    my $min_cpu_lightload = min(@cpu_lite_load);

    # Increasing the load in the system using package stress-ng.
    add_suseconnect_product(get_addon_fullname('phub')) if (is_sle);
    zypper_call('in stress-ng');
    assert_script_run("rpm -q stress-ng");
    my $total_cpu = script_output("cat /proc/cpuinfo | grep processor | wc -l");
    my $total_mem = script_output("free -h | awk '/Mem\:/ { print \$2 }'");
    if ($total_cpu == 1) { $cpu = $total_cpu; } else { $cpu = floor($total_cpu * 0.75); }
    $vm = 50;
    my $stressng_pkg = "nohup stress-ng --cpu $cpu --vm $vm --vm-bytes 10m --timeout 60s&";
    my $bg_pid       = background_script_run($stressng_pkg);
    validate_script_output("echo $bg_pid", sub { m/\d+/ });
    sleep 5;

    # Running vmstat during the high load and storing the result in file. calculate the average of idle memory
    assert_script_run("vmstat 2 10 > /tmp/output_load.log");
    assert_script_run("cat /tmp/output_load.log");

    #kill the running background process stress-ng.
    assert_script_run("pkill -9 stress-ng");

    my ($mem_hvy_ref, $cpu_hvy_ref) = read_memory_cpu("/tmp/output_load.log");
    my @mem_hvy           = @$mem_hvy_ref;
    my @cpu_hvy           = @$cpu_hvy_ref;
    my $avg_mem_heavyload = average(@mem_hvy);
    my $avg_cpu_heavyload = average(@cpu_hvy);

    # Comparision of the vmstat with and without load
    if ($avg_mem_heavyload > $min_mem_lightload or $avg_cpu_heavyload < $min_cpu_lightload) {
        die "Error!! vmstat sample output during light/heavy load";
    }
}

1;

