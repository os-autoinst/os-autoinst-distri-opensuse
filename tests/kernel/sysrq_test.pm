# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test Linux Magic System Request functionality.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use Kernel::magic_sysrq;

sub run {
    my $self = shift;

    select_console 'root-console';

    if (sysrq_check_kconfig()) {

        unless (sysrq_display_help()) {
            $self->result('fail');
            record_info('FAIL', 'alt-sysrq-a: no help menu printed', result => 'fail');
        }

        unless (sysrq_dump_all_cpu_backtrace()) {
            $self->result('fail');
            record_info('FAIL', 'alt-sysrq-l: show-backtrace-all-active-cpus', result => 'fail');
        }

        unless (sysrq_show_memory()) {
            $self->result('fail');
            record_info('FAIL', 'alt-sysrq-m: show-memory-usage', result => 'fail');
        }

        unless (sysrq_dump_curr_regs_flags()) {
            $self->result('fail');
            record_info('FAIL', 'alt-sysrq-p: show-registers', result => 'fail');
        }
    } else {
        $self->result('fail');
        record_info('FAIL', 'Kernel has no support for Magic System Request', result => 'fail');
    }
}

1;

=head1 Description

This module verifies the functionality of the Linux kernel's
Magic System Request (SysRq) keys. It uses subroutines from
Kernel::magic_sysrq module.

=cut
