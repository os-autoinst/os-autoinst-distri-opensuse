# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: fio util-linux
# Summary: This modules verifies we have correct spreading of NVMe
# interrupts across all NUMA nodes, especially when the number of
# nodes exceeds the number of queues the device has.
# Maintainer: Michael Moese <mmoese@suse.de>


use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $numcpu = get_required_var('QEMUCPUS');
    my @interrupts;
    my @irqs;    # number of interrupts by cpu
    my $numqueues;    # number of NVMe queues, each queue has it's own MSI
    my $fail = 0;

    select_serial_terminal;

    $numqueues = script_output('grep -c nvme /proc/interrupts');
    record_info('INFO', "The VM has $numqueues NVMe queues and $numcpu CPUs");
    if ($numcpu <= $numqueues || !check_var('QEMU_NUMA', 1)) {
        die("This test requires the system to have more NUMA nodes than NVMe queues!");
    }

    # install and run fio to generate some interrupts
    zypper_call('install fio');
    assert_script_run("fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=random_read_write --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75 --max-jobs=$numcpu");

    my $fields = 3 + $numcpu - 1;    # calculete fields to select with cut
    @interrupts = split('\n', script_output("grep nvme /proc/interrupts | sed -E -e \'s/[[:blank:]]+/ /g\' | cut -d \' \' -f 3-$fields"));

    # ignore the first queue, this should be the admin queue. This doesn't
    # do too much and propably will only be handled on node 0, so we skip it here.
    for (my $queue = 1; $queue <= $numqueues; $queue++) {
        my @thisqueue = split(' ', $interrupts[$queue]);
        for (my $i = 0; $i <= $numcpu; $i++) {
            $irqs[$i] += $thisqueue[$i];
        }
    }

    for (my $j = 0; $j < $numcpu; $j++) {
        # just report the number of IRQs handled per NUMA node
        record_info("$irqs[$j]", "$irqs[$j] interrupts on CPU#$j");

        # no need to check the first nodes. We are only interestesd if IRQs are
        # also handled on the NUMA nodes with a higher number than the number of
        # queues on the NVMe.
        if ($j > $numqueues) {
            if ($irqs[$j] == "0") {
                die("IRQs don't get distributed equally");
            }
        }
    }
}

sub post_fail_hook {
    my $self = shift;

    select_serial_terminal;

    script_run('cat /proc/interrupts > /tmp/interrupts.txt');
    upload_logs('/tmp/interrupts.txt');
    script_run('lscpu > /tmp/lscpu.txt');
    upload_logs('/tmp/lscpu.txt');

    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Configuration

=head2 Requirements for runtime environment

Basically, nothing much is needed on the SUT to run this test except fio.
So if you are running SLE, you typically don't need any special modules.

=head2 Requirements for QEMU configuration

To run this testsuite, you need to have your disk configured as NVMe, with
a number of queues that is smaller than the number of NUMA nodes in the SUT.
In addition, you need to ensure you give the SUT enough memory, as it gets split
among the NUMA nodes.

=head2 Example testsuite

Example testsuite to run the irq balancing tests:

BOOT_HDD_IMAGE=1
HDDMODEL_1=nvme
HDDNUMQUEUES_1=4
NUMA_IRQBALANCE=1
QEMUCPUS=8
QEMURAM =4096
QEMU_NUMA=1

