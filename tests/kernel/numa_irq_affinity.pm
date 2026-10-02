# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check that the kernel spreads NVMe IRQ affinity across all NUMA
# nodes, also when there are fewer I/O queues than NUMA nodes.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use Kernel::block_dev 'is_block_device';

=head2 get_cpu_numa_map

Return a hashref of CPU to NUMA node from C<lscpu>, and the number of nodes.

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

Return the NVMe lines of C</proc/interrupts>.

=cut

sub get_nvme_interrupt_lines {
    return split("\n", script_output('grep nvme /proc/interrupts'));
}

=head2 get_nvme_queue_irqs

Return a hashref C<{irq, name, admin}> for each NVMe queue IRQ. Queue
C<q0> is the admin queue.

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

=head2 get_irq_proc_values

Return a hashref of IRQ to the value of C</proc/irq/$irq/$file>.

=cut

sub get_irq_proc_values {
    my ($file, @irqs) = @_;
    my %values;
    return \%values unless @irqs;

    my $cmd = '';
    for my $irq (@irqs) {
        $cmd .= "echo IRQ=$irq; cat /proc/irq/$irq/$file; ";
    }
    my @lines = split("\n", script_output($cmd));

    my $current_irq;
    for my $line (@lines) {
        if ($line =~ /^IRQ=(\d+)$/) {
            $current_irq = $1;
        }
        elsif (defined($current_irq)) {
            $values{$current_irq} = $line;
        }
    }
    return \%values;
}

=head2 expand_affinity_to_nodes

Return the NUMA nodes of the CPUs in an affinity list, e.g. C<'0-1,4'>.

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

=head2 get_nvme_block_devices

Return the block device C</dev/nvmeXn1> of each NVMe controller in
C<@queues>. Die if a device does not exist.

=cut

sub get_nvme_block_devices {
    my (@queues) = @_;
    my %controllers;
    for my $queue (@queues) {
        $controllers{$1} = 1 if ($queue->{name} =~ /^(nvme\d+)/);
    }
    my @devices;
    for my $ctrl (sort(keys(%controllers))) {
        push(@devices, "/dev/${ctrl}n1");
    }
    is_block_device(@devices);
    return @devices;
}

=head2 get_effective_queue_counts

Return a hashref of IRQ to its interrupt count on the CPU given for it in
C<$effective>.

=cut

sub get_effective_queue_counts {
    my ($effective) = @_;
    my %counts;
    for my $line (get_nvme_interrupt_lines()) {
        my @fields = split(' ', $line);
        my $irq = shift(@fields);
        $irq =~ s/://;
        next unless defined($effective->{$irq});
        $counts{$irq} = $fields[$effective->{$irq}] // 0;
    }
    return \%counts;
}

sub run {
    my $numcpu = get_required_var('QEMUCPUS');

    select_serial_terminal;

    die('This test requires a NUMA-enabled VM (QEMU_NUMA=1)!') unless check_var('QEMU_NUMA', 1);

    install_package('fio');

    my ($cpu_to_node, $numnodes) = get_cpu_numa_map();
    record_info('INFO', "The VM has $numnodes NUMA nodes and $numcpu CPUs");
    die('This test requires more than one NUMA node!') if ($numnodes <= 1);

    my @queues = get_nvme_queue_irqs();
    my $numqueues = scalar(@queues);
    record_info('INFO', "The VM has $numqueues NVMe queues");
    die("This test requires the system to have more CPUs ($numcpu) than NVMe queues ($numqueues)!") if ($numcpu <= $numqueues);

    # The admin queue is not part of the I/O queue spreading.
    my @io_irqs;
    for my $queue (@queues) {
        push(@io_irqs, $queue->{irq}) unless $queue->{admin};
    }
    my $affinity_lists = get_irq_proc_values('smp_affinity_list', @io_irqs);

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

    # Check each queue, not each NUMA node: one CPU serves a managed IRQ,
    # so with fewer queues than nodes, some nodes get no interrupts.
    my @devices = get_nvme_block_devices(@queues);
    record_info('INFO', 'Testing NVMe device(s): ' . join(', ', @devices));
    my $effective = get_irq_proc_values('effective_affinity_list', @io_irqs);
    my $before = get_effective_queue_counts($effective);

    assert_script_run(
        'fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 '
          . '--name=test --filename=' . join(':', @devices) . ' --bs=4k --iodepth=64 '
          . '--size=1G --readwrite=randrw --rwmixread=75 --runtime=20 --time_based '
          . "--numjobs=$numcpu --cpus_allowed=0-" . ($numcpu - 1) . ' --cpus_allowed_policy=split',
        timeout => 120
    );

    my $after = get_effective_queue_counts($effective);

    my @idle_irqs;
    for my $irq (@io_irqs) {
        my $delta = $after->{$irq} - $before->{$irq};
        record_info("IRQ$irq", "$delta new interrupts on elected CPU $effective->{$irq}");
        push(@idle_irqs, $irq) if ($delta == 0);
    }
    if (@idle_irqs) {
        die('No new interrupts were observed on I/O queue IRQ(s): ' . join(', ', @idle_irqs));
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
    script_run('for f in /proc/irq/*/smp_affinity_list; do echo "$f:"; cat "$f"; done > /tmp/smp_affinity.txt');
    upload_logs('/tmp/smp_affinity.txt');

    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Configuration

=head2 Requirements for QEMU configuration

A second disk with NVMe and fewer I/O queues than NUMA nodes. C<QEMUSOCKETS>
must equal C<QEMUCPUS>, otherwise the kernel reports an invalid topology at
boot.

=head2 Example testsuite

YAML_SCHEDULE=schedule/kernel/numa_irq_affinity.yaml
DESKTOP=textmode
VIDEOMODE=text
BOOT_HDD_IMAGE=1
NUMDISKS=2
HDDMODEL_2=nvme
HDDNUMQUEUES_2=4
QEMUCPUS=5
QEMUSOCKETS=5
QEMU_NUMA=1
