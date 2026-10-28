# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test Linux Kernel's maxcpus boot parameter
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use bootloader_setup qw(grub_mkconfig add_grub_cmdline_settings remove_grub_cmdline_settings);
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';
use Kernel::cpu qw(get_cpu_count);
use testapi;
use utils;

sub run {
    my $self = shift;

    select_serial_terminal;
    my $num_proc = get_cpu_count();
    my $max_cpus = get_var('MAXCPUS', 4);

    die "Invalid MAXCPUS ($max_cpus): must be between 1 and " . ($num_proc - 1)
      if ($max_cpus < 1 || $max_cpus >= $num_proc);

    # Test for maxcpus Kernel command line argument
    # The value provided in maxcpus kernel parameter is only applicable for the duration of kernel bootup
    # other offline CPUs can later be brought online via sysfs or via kernel module(s)
    record_info('maxcpus', "Current: $num_proc\nMaxcpus: $max_cpus");
    add_grub_cmdline_settings("maxcpus=$max_cpus", update_grub => 1);
    power_action('reboot', textmode => 1);
    $self->wait_boot(textmode => 1);

    select_serial_terminal;

    my $match_pattern = 'kernel:\s(BUG|Oops|Tainted|Call\sTrace):[\s\S]*?0x[0-9a-fA-F]{1,4}\/*.?';
    my ($kern_log) = script_output("journalctl -b --no-pager", proceed_on_failure => 1) =~ m/($match_pattern)/i;
    record_info('KERNEL', "Kernel taint detected") if (defined $kern_log && $kern_log =~ /\b(0[xX])[0-9a-fA-F]+\b/);

    validate_script_output("journalctl -b --grep='Total of $max_cpus'", sub { m/Total of $max_cpus processors activated/ });
    remove_grub_cmdline_settings("maxcpus=$max_cpus");
    grub_mkconfig;
}

1;

=head1 Description

This module provides subroutines to test and validate the
functionality of the Linux kernel's maxcpus and nr_cpus boot
parameter.

=cut

