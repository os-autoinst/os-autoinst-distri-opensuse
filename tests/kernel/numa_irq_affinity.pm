# SUSE's openQA tests
#
# Copyright 2019-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module verifies that the kernel spreads NVMe interrupt
# affinity across all NUMA nodes, especially when the number of nodes
# exceeds the number of hardware queues the device has.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

=head2 get_cpu_numa_map

Read the CPU to NUMA node mapping from C<lscpu> and return a hashref of
CPU number to node number, plus the number of distinct NUMA nodes.

=cut

sub get_cpu_numa_map {
    my %cpu_to_node;
    my %nodes;
    my @lines = split("\n", script_output('lscpu -p=CPU,NODE'));
    for my $line (@lines) {
        next if ($line =~ /^#/);
        my ($cpu, $node) = split(',', $line);
        $cpu_to_node{$cpu} = $node;
        $nodes{$node} = 1;
    }
    return (\%cpu_to_node, scalar(keys(%nodes)));
}

=head2 get_nvme_interrupt_lines

Return the lines of C</proc/interrupts> that belong to NVMe queues.

=cut

sub get_nvme_interrupt_lines {
    return split("\n", script_output('grep nvme /proc/interrupts'));
}

=head2 get_nvme_queue_irqs

Return a list of hashrefs C<{irq, name, admin}> for every NVMe MSI-X
interrupt found in C</proc/interrupts>. A queue is flagged as the
admin queue of its controller by its name, e.g. C<nvme0q0>.

=cut

sub get_nvme_queue_irqs {
    my @queues;
    for my $line (get_nvme_interrupt_lines()) {
        my @fields = split(' ', $line);
        my $irq = shift(@fields);
        $irq =~ s/://;
        my $name = $fields[-1];
        push(@queues, {irq => $irq, name => $name, admin => ($name =~ /q0$/ ? 1 : 0)});
    }
    return @queues;
}

=head2 get_irq_affinity_lists

Read the effective CPU affinity of a list of IRQs in a single round trip
to the SUT. Returns a hashref of IRQ number to its raw affinity list
string, e.g. C<{24 =E<gt> '0-1', 25 =E<gt> '2-3'}>, as found in
C</proc/irq/$irq/effective_affinity_list>.

=cut

sub get_irq_affinity_lists {
    my (@irqs) = @_;
    my %affinity;
    return \%affinity unless @irqs;

    my $cmd = '';
    for my $irq (@irqs) {
        $cmd .= "echo IRQ=$irq; cat /proc/irq/$irq/effective_affinity_list; ";
    }
    my @lines = split("\n", script_output($cmd));

    my $current_irq;
    for my $line (@lines) {
        if ($line =~ /^IRQ=(\d+)$/) {
            $current_irq = $1;
        }
        elsif (defined($current_irq)) {
            $affinity{$current_irq} = $line;
        }
    }
    return \%affinity;
}

=head2 expand_affinity_to_nodes

Resolve a raw affinity list string (e.g. C<'0-1,4'>) into the set of NUMA
nodes it touches, using the CPU to node map from L</get_cpu_numa_map>.

=cut

sub expand_affinity_to_nodes {
    my ($affinity, $cpu_to_node) = @_;
    my %nodes;
    for my $part (split(',', $affinity)) {
        if ($part =~ /^(\d+)-(\d+)$/) {
            for (my $cpu = $1; $cpu <= $2; $cpu++) {
                $nodes{$cpu_to_node->{$cpu}} = 1 if defined($cpu_to_node->{$cpu});
            }
        }
        elsif ($part =~ /^(\d+)$/) {
            $nodes{$cpu_to_node->{$1}} = 1 if defined($cpu_to_node->{$1});
        }
    }
    return keys(%nodes);
}

=head2 get_interrupt_counts_per_node

Sum the per-CPU interrupt counts of every NVMe queue (admin and I/O) from
C</proc/interrupts> and aggregate them per NUMA node. NUMA nodes are
assumed to be numbered contiguously from 0, as reported by C<lscpu>.

=cut

sub get_interrupt_counts_per_node {
    my ($numcpu, $cpu_to_node, $numnodes) = @_;
    my @per_node = (0) x $numnodes;
    for my $line (get_nvme_interrupt_lines()) {
        $line =~ s/^\s*\d+:\s*//;
        my @counts = split(' ', $line);
        for (my $cpu = 0; $cpu < $numcpu; $cpu++) {
            next unless defined($cpu_to_node->{$cpu});
            $per_node[$cpu_to_node->{$cpu}] += $counts[$cpu] // 0;
        }
    }
    return @per_node;
}

sub run {
    my $numcpu = get_required_var('QEMUCPUS');

    select_serial_terminal;

    die('This test requires a NUMA-enabled VM (QEMU_NUMA=1)!') unless check_var('QEMU_NUMA', 1);

    my ($cpu_to_node, $numnodes) = get_cpu_numa_map();
    record_info('INFO', "The VM has $numnodes NUMA nodes and $numcpu CPUs");
    die('This test requires more than one NUMA node!') if ($numnodes <= 1);

    my @queues = get_nvme_queue_irqs();
    my $numqueues = scalar(@queues);
    record_info('INFO', "The VM has $numqueues NVMe queues");
    die("This test requires the system to have more CPUs ($numcpu) than NVMe queues ($numqueues)!") if ($numcpu <= $numqueues);

    # Static check: the kernel assigns each queue's IRQ affinity at device
    # probe time, independent of any load. If that assignment alone doesn't
    # already cover every NUMA node, no amount of I/O will make it do so.
    # The admin queue is excluded, as it is not part of the I/O spreading.
    my @io_irqs;
    for my $queue (@queues) {
        push(@io_irqs, $queue->{irq}) unless $queue->{admin};
    }
    my $affinity_lists = get_irq_affinity_lists(@io_irqs);

    my %covered_nodes;
    for my $irq (@io_irqs) {
        for my $node (expand_affinity_to_nodes($affinity_lists->{$irq}, $cpu_to_node)) {
            $covered_nodes{$node} = 1;
        }
    }
    my @missing_nodes;
    for (my $node = 0; $node < $numnodes; $node++) {
        push(@missing_nodes, $node) unless $covered_nodes{$node};
    }
    if (@missing_nodes) {
        die('NVMe queue IRQ affinity does not cover NUMA node(s): ' . join(', ', @missing_nodes));
    }
    record_info('AFFINITY OK', 'NVMe queue IRQ affinity covers all NUMA nodes');

    # Functional check: confirm interrupts are actually delivered on every
    # node under load, not just theoretically affine to it. The snapshot is
    # taken before installing fio, since the install itself causes disk I/O.
    my @before = get_interrupt_counts_per_node($numcpu, $cpu_to_node, $numnodes);

    zypper_call('install fio');
    assert_script_run(
        'fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 '
          . '--name=test --filename=/tmp/random_read_write --bs=4k --iodepth=64 '
          . '--size=1G --readwrite=randrw --rwmixread=75 --runtime=20 --time_based '
          . "--numjobs=$numcpu --cpus_allowed=0-" . ($numcpu - 1) . ' --cpus_allowed_policy=split',
        timeout => 120
    );

    my @after = get_interrupt_counts_per_node($numcpu, $cpu_to_node, $numnodes);

    my @idle_nodes;
    for (my $node = 0; $node < $numnodes; $node++) {
        my $delta = $after[$node] - $before[$node];
        record_info("NODE$node", "$delta new interrupts on NUMA node $node");
        push(@idle_nodes, $node) if ($delta == 0);
    }
    if (@idle_nodes) {
        die('No new interrupts were observed on NUMA node(s): ' . join(', ', @idle_nodes));
    }
}

sub post_fail_hook {
    my $self = shift;

    select_serial_terminal;

    script_run('cat /proc/interrupts > /tmp/interrupts.txt');
    upload_logs('/tmp/interrupts.txt');
    script_run('lscpu > /tmp/lscpu.txt');
    upload_logs('/tmp/lscpu.txt');
    script_run('for f in /proc/irq/*/effective_affinity_list; do echo "$f:"; cat "$f"; done > /tmp/irq_affinity.txt');
    upload_logs('/tmp/irq_affinity.txt');

    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Configuration

=head2 Requirements for runtime environment

Nothing extra is needed on the SUT except fio, which this module installs
itself.

=head2 Requirements for QEMU configuration

To run this testsuite, you need to have your disk configured as NVMe, with
a number of queues that is smaller than the number of NUMA nodes in the SUT.
In addition, you need to ensure you give the SUT enough memory, as it gets
split among the NUMA nodes.

=head2 Example testsuite

Scheduled via C<schedule/kernel/numa_irq_affinity.yaml>:

BOOT_HDD_IMAGE=1
HDDMODEL_1=nvme
HDDNUMQUEUES_1=4
QEMUCPUS=8
QEMURAM=4096
QEMU_NUMA=1
