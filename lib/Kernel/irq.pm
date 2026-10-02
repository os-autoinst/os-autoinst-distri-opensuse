# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Interrupt helpers for kernel tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::irq;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT_OK = qw(
  get_interrupts
  get_irq_total
);

=head1 SYNOPSIS

Interrupt helpers for kernel tests.

Take a snapshot of C</proc/interrupts> before and after a workload and
compare the counters of the interrupts of interest:

 my @irqs = (40, 41);    # the interrupts of interest
 my $before = get_interrupts();
 # run the workload
 my $after = get_interrupts();
 my $delta = get_irq_total($after, @irqs) - get_irq_total($before, @irqs);

=cut

sub _parse_interrupts {
    my ($text) = @_;
    my ($header, @lines) = split /\n/, $text // '';
    my @cpus = ($header // '') =~ /CPU(\d+)/g;
    die 'No CPU columns in /proc/interrupts' unless @cpus;

    my %irqs;
    for my $line (@lines) {
        next unless $line =~ /^\s*(\w+):\s*(.*)$/;
        my ($name, @fields) = ($1, split(' ', $2));
        my @counts;
        push @counts, shift @fields while @fields && @counts < @cpus && $fields[0] =~ /^\d+$/;
        $irqs{$name} = {counts => \@counts, desc => join(' ', @fields)};
    }
    return {cpus => \@cpus, irqs => \%irqs};
}

=head2 get_interrupts

 my $snapshot = get_interrupts();

Reads C</proc/interrupts> on the SUT and returns a hash reference with:

=over

=item * C<cpus>: array reference of the CPU numbers of the counter
columns. CPU numbers are not always contiguous, for example if CPUs are
offline.

=item * C<irqs>: hash reference of the interrupt name (C<40>, C<NMI>,
C<LOC>, ...) to a hash reference with C<counts>, the per-CPU counters in
the order of C<cpus>, and C<desc>, the rest of the line (chip and name).

=back

Rows like C<ERR> and C<MIS> have one counter, not one per CPU.

=cut

sub get_interrupts {
    return _parse_interrupts(script_output('cat /proc/interrupts'));
}

sub _irq {
    my ($snapshot, $irq) = @_;
    my $row = $snapshot->{irqs}{$irq};
    die "IRQ $irq is missing from /proc/interrupts" unless $row;
    return $row;
}

=head2 get_irq_total

 my $count = get_irq_total($snapshot, @irqs);

Returns the sum of the counters of all CPUs for the given interrupts of a
snapshot from C<get_interrupts()>. Dies if an interrupt is missing.

=cut

sub get_irq_total {
    my ($snapshot, @irqs) = @_;
    my $total = 0;
    for my $irq (@irqs) {
        $total += $_ for @{_irq($snapshot, $irq)->{counts}};
    }
    return $total;
}

1;
