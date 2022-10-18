# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-storage
# Summary: yast storage test
# List disks and list partitions
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;
    zypper_call "in yast2-storage";
    #    assert_script_run 'yast disk list disks';
    #    assert_script_run 'yast disk list partitions';
    #
    my $lsblk_output = script_output("lsblk");
    my $list_disks_output = script_output("yast disk list disks");
    my $list_part_output = script_output("yast disk list partitions");

    # Checks that all disks listed by 'lsblk' are part of 'yast disk list disks'
    my $current_test_device;
    my $found;
    my @tested_devices;
    for my $lsblk_line (split /^/, $lsblk_output) {
        if ($lsblk_line =~ /^([a-z]d[a-z])(.*)disk/) {
            $current_test_device = $1;
            $found = 0;
            for my $list_disks_line (split /^/, $list_disks_output) {
                if ($list_disks_line =~ /^(.*)$current_test_device/) {
                    $found++;
                    push @tested_devices, $current_test_device;
                }
            }
            die "Could not find disk match between lsblk and yast disk list disks" unless ($found);
        }
    }
    die "Could not find a valid block device to test" unless (@tested_devices);

    # Checks that all partitions listed by 'lsblk' are part of 'yast disk list partitions'
    my @part_not_matched;
    @tested_devices = ();

    for my $lsblk_line (split /^/, $lsblk_output) {
        if ($lsblk_line =~ /([a-z]d[a-z][1-9]+)(.*)part/) {
            $current_test_device = $1;
            $found = 0;
            for my $list_part_line (split /^/, $list_part_output) {
                if ($list_part_line =~ /^(.*)$current_test_device/) {
                    $found++;
                    push @tested_devices, $current_test_device;
                }
            }
            unless ($found) {
                push @part_not_matched, $current_test_device;
            }
        }
    }
    die "Could not find a valid partition to test" unless (@tested_devices);

    # Some partitions may not be listed in 'yast disk list partitions' due to a known issue.
    if (@part_not_matched) {
        record_soft_failure 'bsc#1150450';
    }
}

1;
