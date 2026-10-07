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
  get_irq_per_cpu
  get_irq_remapped
  get_irqs_in_use
  get_device_irqs
  get_irq_affinity
  set_irq_affinity
);

=head1 SYNOPSIS

Interrupt helpers for kernel tests.

Take a snapshot of C</proc/interrupts> before and after a workload and
compare the counters of the interrupts of interest:

 my @irqs = get_device_irqs($controller);
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

=head2 get_irq_per_cpu

 my $counts = get_irq_per_cpu($snapshot, @irqs);

Returns a hash reference of the CPU number to the sum of the counters of
the given interrupts on that CPU. Dies if an interrupt is missing.

=cut

sub get_irq_per_cpu {
    my ($snapshot, @irqs) = @_;
    my @cpus = @{$snapshot->{cpus}};
    my %counts = map { $_ => 0 } @cpus;
    for my $irq (@irqs) {
        my $row = _irq($snapshot, $irq)->{counts};
        $counts{$cpus[$_]} += $row->[$_] for 0 .. $#$row;
    }
    return \%counts;
}

=head2 get_irq_remapped

 my $remapped = get_irq_remapped($snapshot, @irqs);

Returns a hash reference of each given interrupt to 1 if it goes through
interrupt remapping (Intel VT-d or AMD-Vi), else 0, from a snapshot from
C<get_interrupts()>. Dies if an interrupt is missing.

On x86_64, the chip name of a remapped interrupt in C</proc/interrupts>
starts with C<IR->, for example C<IR-PCI-MSIX-0000:02:00.0> or
C<IR-IO-APIC>. Other architectures do not use this prefix, so all
interrupts are reported as not remapped there.

=cut

sub get_irq_remapped {
    my ($snapshot, @irqs) = @_;
    return {map { $_ => (_irq($snapshot, $_)->{desc} =~ /^IR-/ ? 1 : 0) } @irqs};
}

=head2 get_irqs_in_use

 my @in_use = get_irqs_in_use($snapshot, @irqs);

Returns the given interrupts that have a row in a snapshot from
C<get_interrupts()>, in the given order. A driver can reserve more
interrupts than it uses: C<get_device_irqs()> returns all reserved
interrupts, but only interrupts that the driver requested appear in
C</proc/interrupts>. For example, a network card reserves interrupts for
an RDMA driver that is not loaded, and the driver of a network interface
that is down requests none.

=cut

sub get_irqs_in_use {
    my ($snapshot, @irqs) = @_;
    my @in_use = grep { exists $snapshot->{irqs}{$_} } @irqs;
    diag("IRQs: @irqs; in use: @in_use");
    return @in_use;
}

=head2 get_device_irqs

 my @irqs = get_device_irqs($sysfs_path);

Returns the interrupt numbers of a PCI device, for example
C</sys/devices/pci0000:00/0000:00:01.0>. These are the MSI or MSI-X
interrupts from C<msi_irqs> if the device uses them, else the legacy
interrupt from C<irq>. Dies if the device has no interrupt. These are the
interrupts that the driver reserved; see C<get_irqs_in_use()> for the
interrupts that it uses.

=cut

sub get_device_irqs {
    my ($device) = @_;
    # A device that uses MSI or MSI-X has a msi_irqs/ directory with one file
    # per interrupt, named by its IRQ number. Other devices have a single
    # legacy interrupt, whose IRQ number is in the irq file.
    my $irqs = script_run("test -d $device/msi_irqs") == 0
      ? script_output("ls $device/msi_irqs")
      : script_output("cat $device/irq");
    diag("Interrupts of $device: $irqs");
    my @irqs = split ' ', $irqs;
    die "No usable interrupts for $device" unless @irqs && !grep { !/^[1-9]\d*$/ } @irqs;
    return sort { $a <=> $b } @irqs;
}

=head2 get_irq_affinity

 my $affinity = get_irq_affinity(@irqs);

Returns a hash reference of each given interrupt to the CPUs that it may
run on, as the kernel CPU list from C</proc/irq/N/smp_affinity_list>, for
example C<0-7,32-39>. Reads all interrupts with one command.

=cut

sub get_irq_affinity {
    my (@irqs) = @_;
    return {} unless @irqs;
    my %affinity;
    my $output = script_output("for irq in @irqs; do echo \"\$irq \$(cat /proc/irq/\$irq/smp_affinity_list 2>/dev/null)\"; done");
    for my $line (split /\n/, $output) {
        $affinity{$1} = $2 if $line =~ /^(\d+) ([\d,-]+)$/;
    }
    die "No affinity for IRQ $_" for grep { !defined $affinity{$_} } @irqs;
    return \%affinity;
}

=head2 set_irq_affinity

 my @refused = set_irq_affinity(298 => '0', 299 => '16', ...);

Sets the CPUs that each given interrupt may run on, as a kernel CPU list
written to C</proc/irq/N/smp_affinity_list>, with one command. Returns the
interrupts whose affinity the kernel refused, for example interrupts that
the kernel manages itself, such as the queue interrupts of NVMe. A running
irqbalance can change the affinity again later.

=cut

sub set_irq_affinity {
    my (%cpus) = @_;
    return () unless %cpus;
    my $pairs = join ' ', map { "$_:$cpus{$_}" } sort { $a <=> $b } keys %cpus;
    my $refused = script_output("for pair in $pairs; do irq=\${pair%%:*}; "
          . "{ echo \${pair#*:} > /proc/irq/\$irq/smp_affinity_list; } 2>/dev/null || echo \$irq; done");
    return grep { /^\d+$/ } split ' ', $refused;
}

1;
