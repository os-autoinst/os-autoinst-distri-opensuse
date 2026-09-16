# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Magic SysRq helpers shared across kernel test modules.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::magic_sysrq;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  sysrq_dump_all_cpu_backtrace
  sysrq_dump_curr_regs_flags
  sysrq_dump_curr_tasks
  sysrq_check_kconfig
  sysrq_display_help
  sysrq_show_memory
);

=head2 sysrq_display_help

sysrq_display_help();

Sends C<alt-sysrq-a> key to print magic sysrq help menu, parses journalctl log for
the presence of magic sysrq help pattern. Returns C<1> if pattern is found
returns C<0> otherwise.

=cut

sub sysrq_display_help {
    send_key 'alt-sysrq-a';
    my $out = script_output('journalctl -k -n3 | grep -Pzo "sysrq:.*HELP\s:.*\)"', proceed_on_failure => 1);

    return 0 unless ($out =~ /loglevel\(0-9\)\s.*\)/);
    return 1;
}

=head2 sysrq_dump_all_cpu_backtrace

sysrq_dump_all_cpu_backtrace();

Sends C<alt-sysrq-l> key combination to print all cpu backtrace, parses
C<journalctl> log for backtrace pattern ending with "/TASK" and checks for
presence of hex numbers representing CPU register values.
Returns C<1> if pattern is found else C<0>.

=cut

sub sysrq_dump_all_cpu_backtrace {
    send_key 'alt-sysrq-l';
    my $out = script_output('journalctl -k -n100 | grep -Pzo "(?is)sysrq:.*CPUs(.*?(?:r15|r31|x29|x31|kr15|pstate|psw)[^\n:]*:\s*[0-9a-f]+)"',
        proceed_on_failure => 1);

    return 0 unless ($out =~ /\b(0[xX])[0-9a-fA-F]+\b/);
    return 1;
}

=head2 sysrq_show_memory

sysrq_show_memory();

Sends C<alt-sysrq-m> key combination to print memory information, parses
C<journalctl> log to search for sysrq Memory Info pattern and checks for
presence of string "Total swap". Returns C<1> if string pattern is found
otherwise C<0>.

=cut

sub sysrq_show_memory {
    send_key 'alt-sysrq-m';
    my $out = script_output('journalctl -k -n25 | grep -Pzo "sysrq:.*Show\sMemory.*[\s\S]*.Mem-Info:.*[\s\S]*.Total\sswap\s=\s[0-9]*?kB"',
        proceed_on_failure => 1);

    return 0 unless ($out =~ /Free\sswap.*=\s[0-9].*kB/);
    return 1;
}

=head2 sysrq_dump_curr_regs_flags

sysrq_dump_curr_regs_flags();

Sends the C<alt-sysrq-p> keystroke to trigger a dump of the current CPU
registers and flags to the kernel ring buffer. It then checks the C<journalctl>
logs to verify that the expected register state output (e.g., C<CPU#0:>) was
successfully captured. Returns C<1> if the CPU register dump is successfully
found in the logs, or C<0> if the expected output is missing.

=cut

sub sysrq_dump_curr_regs_flags {
    send_key 'alt-sysrq-p';
    my $out = script_output('journalctl -k -n1000 | grep -Pzo "sysrq:.*Show\sRegs[\s\S]*.gen-PMC[0-9]\s\w.*:"', proceed_on_failure => 1);

    return 0 unless ($out =~ /CPU\#[0-9]{1,4}:\s?.*[0-9a-fA-F]/);
    return 1;
}

=head2 sysrq_dump_curr_tasks

sysrq_dump_curr_tasks();

Sends the C<alt-sysrq-t> keystroke to trigger a dump of the current tasks and
thread states to the kernel ring buffer. It evaluates a larger portion of the
C<journalctl> logs (up to 10,000 lines) with an extended timeout to verify that
the task state information (specifically looking for C<runnable tasks:>) was
successfully recorded. Returns C<1> if the task state dump is successfully found
in the logs, or C<0> if the expected output is missing.

=cut

sub sysrq_dump_curr_tasks {
    send_key 'alt-sysrq-t';
    my $out = script_output('journalctl -k -n10000 | grep -Pzo "sysrq:.*Show\sState[\s\S]*.worker\spools:"', timeout => 180, proceed_on_failure => 1);

    return 0 unless ($out =~ /runnable\stasks:/);
    return 1;
}

=head2 sysrq_check_kconfig

 sysrq_check_kconfig();

Checks whether C<CONFIG_MAGIC_SYSRQ> is set to C<y> in running kernel
configuration. Returns true/false.

=cut

sub sysrq_check_kconfig {
    return script_run('zgrep "CONFIG_MAGIC_SYSRQ=y" /proc/config.gz') == 0;
}

=head1 NAME

Kernel::magic_sysrq - Helper module for testing Linux Magic System Request
functionality in openQA.

=head1 DESCRIPTION

This module provides a suite of helper subroutines for openQA to interact with
and validate the Linux kernel's Magic System Request (SysRq) functionality.

It triggers various SysRq commands by sending specific key combinations
(e.g., C<alt-sysrq-a>) using send_key. It then parses the kernel ring buffer
logs using C<journalctl> to verify that the kernel responded correctly to the
request.

The module exports the following subroutines by default:

=over 4

=item * C<sysrq_dump_all_cpu_backtrace>

=item * C<sysrq_dump_curr_regs_flags>

=item * C<sysrq_dump_curr_tasks>

=item * C<sysrq_check_kconfig>

=item * C<sysrq_display_help>

=item * C<sysrq_show_memory>

=back

=cut

1;

