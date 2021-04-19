# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use partitions_validator_utils 'validate_mounting_option';

sub run {
    my $test_data = get_test_suite_data;
    select_console 'root-console';

    foreach my $disk (@{$test_data->{disks}}) {
        foreach my $partition (@{$disk->{partitions}}) {
            if ($partition->{fstab_options}) {
                validate_mounting_option({
                        partition   => $partition->{name},
                        mount_by    => $partition->{fstab_options}{mount_by},
                        mount_point => $partition->{mounting_options}{mount_point}});
            }
        }
    }
}

1;
