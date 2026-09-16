# SUSE's openQA tests
#
# Copyright 2023-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test Linux Magic System Request functionality.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;

sub validate_display_sysrq_help {
    my $help_pattern = sub { /sysrq:\sHELP\s:.*[\s\S]show.*[\s\S]\)/ };
    validate_script_output('echo a > /proc/sysrq-trigger', $help_pattern);
}

sub validate_dump_all_cpu_backtrace {
    my $backtrace_pattern = sub { /sysrq:\sShow\sbacktrace.*CPUs[\s\S]*?Call\sTrace[\s\S]*?\/TASK/ };
    validate_script_output('echo l > /proc/sysrq-trigger', $backtrace_pattern);
}

sub validate_show_memory {
    my $meminfo_pattern = sub { /sysrq:\sShow\sMemory.*[\s\S]*.Mem-Info:.*[\s\S]*.Total\sswap\s=\s[0-9]*?kB/ };
    validate_script_output('echo m > /proc/sysrq-trigger', $meminfo_pattern);
}

sub validate_dump_curr_regs_flags {
    my $regs_flags_pattern = sub { /sysrq:\sShow\sRegs[\s\S]*.([0-9][a-f])*.?/ };
    validate_script_output('echo p > /proc/sysrq-trigger', $regs_flags_pattern);
}

sub validate_dump_curr_tasks {
    my $curr_tasks_pattern = sub { /Call\sTrace[\s\S]*?<\/TASK>[\s\S]*runnable\stasks:/ };
    validate_script_output('echo t > /proc/sysrq-trigger', $curr_tasks_pattern);
}

sub run {
    my $self = @_;
    my $kernel_magic_sysrq = 0;
    my $can_use_sysrq_trigger = eval { script_run('test -w /proc/sysrq-trigger', timeout => 30) == 0 };

    select_console 'root-console';

    $kernel_magic_sysrq = 1 unless script_run('zgrep "CONFIG_MAGIC_SYSRQ=y" /proc/config.gz');

    if ($kernel_magic_sysrq) {
        validate_display_sysrq_help;
        validate_dump_all_cpu_backtrace;
        validate_show_memory;
        validate_dump_curr_regs_flags;
        validate_dump_curr_tasks;

    } else {
        record_info('INFO', 'Kernel has no support for Magic System Request, skipping sysrq tests');
    }
}

1;
