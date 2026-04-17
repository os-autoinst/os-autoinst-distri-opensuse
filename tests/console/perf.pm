# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perf
# Summary: Test basic perf funcionality
# Maintainer: Orestis Nalmpantis <onalmpantis@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use Utils::Architectures;

# Auxiliar function to filter and group events
sub run_perf_stat_grouped {
    my $raw_list = script_output("perf list --raw-dump");

    # Define groups of events
    my %groups = (
        "CPU_Usage" => [qw(cycles cpu-clock task-clock)],
        "Execution" => [qw(instructions branches branch-misses)],
        "Cache_Memory" => [qw(cache-references cache-misses page-faults)],
        "System_Load" => [qw(bus-cycles context-switches cpu-migrations)]
    );

    foreach my $group_name (sort keys %groups) {
        my @supported;
        foreach my $event (@{$groups{$group_name}}) {
            # Check if event exists in 'perf list'
            push(@supported, $event) if ($raw_list =~ /\b$event\b/);
        }

        if (@supported) {
            my $list = join(',', @supported);
            record_info($group_name, "Testing: $list");
            assert_script_run("perf stat -e $list -a sleep 2");
        } else {
            record_info($group_name, "No events supported for this category");
        }
    }
}

sub run {
    select_serial_terminal;

    # test 1
    # Installing and testing options -a -d -p
    install_package('perf', trup_reboot => 1);
    assert_script_run('perf stat -a -d -p 1 sleep 5');
    # test 2
    # Counting with perf stat
    assert_script_run('perf stat dd if=/dev/zero of=demo bs=4k count=10000');
    assert_script_run('perf record dd if=/dev/zero of=demo bs=4k count=10000');
    script_run('timeout 5 perf report -i perf.data');
    assert_script_run('perf trace ls');
    # test 3
    # Static Tracing (record command)
    assert_script_run('perf stat -e cs dd if=/dev/zero of=demo bs=4k count=10000');
    assert_script_run('perf record -e cs dd if=/dev/zero of=demo bs=4k count=10000');
    script_run('timeout 5 perf report -i perf.data');
    # test4
    # Dynamic Tracing (probe command)
    if (script_run('timeout 10 perf probe --add tcp_sendmsg') != 0) {
        record_info('Run without debuginfod', 'Timeout or wrong symbol address when using debuginfod (boo#1213785)', result => 'softfail');
        if (script_run('DEBUGINFOD_URLS= perf probe --add tcp_sendmsg') != 0) {
            die "Adding perf probe failed" unless is_riscv;
            record_info('Adding tcp_sendmsg probe manually', 'Working around kernel bug (boo#1249436)', result => 'softfail');
            assert_script_run("echo p:probe/tcp_sendmsg tcp_sendmsg >> /sys/kernel/tracing/kprobe_events");
        }
    }
    script_run('perf record -e probe:tcp_sendmsg -aR sleep 10');
    script_run('timeout 5 perf report -i perf.data');
    assert_script_run('perf probe -d tcp_sendmsg');
    # test5
    # Counting Events ( stat command)
    assert_script_run('perf stat ls');
    assert_script_run('perf stat -a sleep 5');

    run_perf_stat_grouped();

    assert_script_run("perf stat -e 'syscalls:sys_enter_*' -a sleep 5");
    assert_script_run("perf stat -e 'block:*' -a sleep 10");
    # test6
    # Listing (list command)
    assert_script_run('timeout 5 perf --no-pager list sw');
    assert_script_run('timeout 5 perf --no-pager list');
}

1;
