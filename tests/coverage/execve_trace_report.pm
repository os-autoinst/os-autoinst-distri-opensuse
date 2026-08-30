# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Collect ftrace sched_process_exec data and upload a binary
#          execution inventory.  Produces two files:
#          - execve_inventory.txt: all executed paths with call counts
#          - execve_elf_binaries.txt: only ELF binaries (scripts filtered out)
#          Pair with coverage/execve_trace_start at the beginning of
#          the schedule.
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Stop tracing
    assert_script_run('echo 0 > /sys/kernel/tracing/tracing_on', timeout => 10);

    # Check for ring buffer overruns
    my $overrun = script_output('cat /sys/kernel/tracing/stats/overrun 2>/dev/null || echo 0', timeout => 10);
    record_info('Overrun', "Ring buffer overruns: $overrun") if $overrun && $overrun ne '0';

    # Extract filenames from sched_process_exec events
    assert_script_run(
        q{grep -oP 'filename=\K\S+' /sys/kernel/tracing/trace | sort | uniq -c | sort -rn > /tmp/execve_inventory.txt},
        timeout => 600
    );

    my $count = script_output('wc -l < /tmp/execve_inventory.txt', timeout => 30);
    record_info('Inventory', "$count unique binaries executed");

    my $top = script_output('head -50 /tmp/execve_inventory.txt', timeout => 30);
    record_info('Top 50', $top);

    # Filter to ELF binaries only (batch xargs + file for speed)
    assert_script_run(
        q{awk '{print $2}' /tmp/execve_inventory.txt | xargs -r file -L 2>/dev/null | grep ELF | cut -d: -f1 > /tmp/execve_elf_binaries.txt},
        timeout => 600
    );

    my $elf_count = script_output('wc -l < /tmp/execve_elf_binaries.txt', timeout => 30);
    record_info('ELF binaries', "$elf_count unique ELF binaries executed");

    upload_logs('/tmp/execve_inventory.txt');
    upload_logs('/tmp/execve_elf_binaries.txt');
}

sub test_flags {
    return {fatal => 0};
}

1;
