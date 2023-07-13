# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the mounting option of each partition
# defined in test data, is set in fstab is as expected.
# Example of test_data syntax:
#
# test_data:
#   disks:
#     - name: vda
#       partitions:
#         - name: vda1
#           mounting_options:
#             mount_point: swap
#           fstab_options:
#             mount_by: UUID
#         - name: vda2
#           mounting_options:
#             mount_point: /
#           fstab_options:
#             mount_by: Device Name
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub validate_mounting_option {
    my $args = shift;
    record_info("Check $args->{partition}",
        "Check if $args->{partition} partition is mounted by $args->{mount_by} option");
    my %mount_by = (
        UUID => "UUID",
        "Device Name" => "/dev/$args->{partition}",
        "Device Path" => "/dev/disk/by-path/");
    assert_script_run("grep \"$mount_by{$args->{mount_by}}\" /etc/fstab | grep \" $args->{mount_point} \"");
}

sub run {
    my $test_data = get_test_suite_data;
    select_console 'root-console';

    foreach my $disk (@{$test_data->{disks}}) {
        foreach my $partition (@{$disk->{partitions}}) {
            if ($partition->{fstab_options}) {
                validate_mounting_option({
                        partition => $partition->{name},
                        mount_by => $partition->{fstab_options}{mount_by},
                        mount_point => $partition->{mounting_options}{mount_point}});
            }
        }
    }
}

1;
