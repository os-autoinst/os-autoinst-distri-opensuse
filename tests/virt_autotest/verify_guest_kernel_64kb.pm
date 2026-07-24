# GUEST 64KB PAGE SIZE VERIFICATION MODULE
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module verifies that each installed guest is running the
# kernel-64kb flavor (64KB page size), mirroring the same check that
# virt_autotest/login_console.pm already performs on the virtualization host.
# poo#126110 - Add ARM 64KB page size VT test for host and guest.
#
# Maintainer: qe-virt@suse.de
package verify_guest_kernel_64kb;

use Mojo::Base 'virt_feature_test_base';
use testapi;
use virt_autotest::common;
use virt_autotest::utils qw(execute_over_ssh);

sub run_test {
    my $self = shift;

    $self->verify_64kb_page_size($_) foreach (keys %virt_autotest::common::guests);
    return $self;
}

=head2 verify_64kb_page_size

  verify_64kb_page_size($self, $guest_name)

Verify guest C<$guest_name> is running kernel-64kb (64KB page size) via dmesg,
then re-initiate its swap area with C<swapon --fixpgsz> so swap page size
matches the running kernel, and finally confirm C<getconf PAGESIZE> reports
65536. This is the guest-side equivalent of the host-side check already done
in virt_autotest/login_console.pm.

=cut

sub verify_64kb_page_size {
    my ($self, $guest_name) = @_;
    # execute_over_ssh only asserts on exit code, so use a plain ssh prefix
    # (same pattern as tests/virt_autotest/uefi_guest_verification.pm) for the
    # one call below that needs to capture command output.
    my $ssh_command_prefix = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";

    record_info("64KB page size check on $guest_name", "Guest kernel should be kernel-64kb flavor");
    execute_over_ssh(address => $guest_name, command => "cat /proc/cmdline");
    execute_over_ssh(address => $guest_name, command => "dmesg | grep 'Linux version' | grep -- -64kb");

    my $swap_partition = script_output("$ssh_command_prefix root\@$guest_name \"swapon | awk '/\\/dev/{print \\\$1; exit}'\"", proceed_on_failure => 1);
    if ($swap_partition) {
        record_info("Re-init swap on $guest_name", "Swap partition is $swap_partition");
        execute_over_ssh(address => $guest_name, command => "swapoff $swap_partition");
        execute_over_ssh(address => $guest_name, command => "swapon --fixpgsz");
    }
    execute_over_ssh(address => $guest_name, command => "getconf PAGESIZE | grep 65536");
    record_info('INFO', "Guest $guest_name has 64KB page size enabled.");
    return $self;
}

1;
