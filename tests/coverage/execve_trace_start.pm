# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable ftrace sched_process_exec tracing to capture all
#          binary executions during a test run. Place this module at
#          the beginning of a schedule (after system_prepare) and pair
#          it with coverage/execve_trace_report at the end.
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    assert_script_run('mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null; true');
    assert_script_run('echo 0 > /sys/kernel/tracing/tracing_on');
    # 16 MB per-CPU ring buffer; enough for a full-length schedule
    assert_script_run('echo 16384 > /sys/kernel/tracing/buffer_size_kb');
    assert_script_run('echo > /sys/kernel/tracing/trace');
    assert_script_run('echo 1 > /sys/kernel/tracing/events/sched/sched_process_exec/enable');
    assert_script_run('echo 1 > /sys/kernel/tracing/tracing_on');
    record_info('Tracing', 'ftrace sched_process_exec enabled');
}

sub test_flags {
    return {fatal => 1};
}

1;
