# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test nvme performance on a L8s_v2 Azure instance
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

# Benchmark the given device with hdparm and fail, if the given threshold [MB/sec] is not reached
sub benchmark_device {
    my ($device, $threshold) = @_;

    my $output = script_output("hdparm -t $device | grep 'Timing buffered disk reads'");
    # e.g. 'Timing buffered disk reads: 15528 MB in  3.00 seconds = 5174.94 MB/sec'
    if ($output =~ "Timing buffered disk reads: (.*)=( )*(?<throughput>[0-9]+\.[0-9]*) MB/sec") {
        my $throughput = $+{throughput};
        record_info("$device", "Throughput: $throughput MB/sec\nThreshold: $threshold MB/sec");
        die "Threshold for $device not reached" if ($throughput < $threshold);
    } else {
        die "Unexpected hdparm output";
    }
}

sub run {
    select_serial_terminal;

    die "This test only works on Azure L instances" unless (get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE') =~ 'L(8|16|32|48|64|80)s_v2');

    # Ensure the required disks are present
    record_info('lsbkl', script_output('lsblk'));
    assert_script_run('lsblk | grep sda', fail_message => "sda disk is not present");
    assert_script_run('lsblk | grep sdb', fail_message => "sdb disk is not present");
    assert_script_run('lsblk | grep nvme0n1', fail_message => "nvme disk is not present");

    # Install required utilities
    zypper_call("in hdparm");

    # Ensure the performance is above the expected values
    # See https://docs.microsoft.com/en-us/azure/virtual-machines/lsv2-series
    benchmark_device("/dev/sdb", 80);
    benchmark_device("/dev/nvme0n1", 2000);
    # Note: L16sv2 has two, L32sv2 has three NVME disks, however we are only testing the first one. This could be extended, if required.
}

1;
