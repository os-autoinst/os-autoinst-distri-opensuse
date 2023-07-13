# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate LUKS version for encrypted partitions not mounted
# in the system using test data. Example:
# test_data:
#   disks:
#     - name: vdb
#       partitions:
#         - name: vdb1
#           formatting_options:
#             luks_type: 2
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $disks = get_test_suite_data()->{disks};
    select_console 'root-console';

    my $luks_type;
    foreach my $disk (@{$disks}) {
        foreach my $part (@{$disk->{partitions}}) {
            $luks_type = $part->{formatting_options}{luks_type};
            record_info("Encryption", "Verify that the partition encryptions is LUKS $luks_type");
            validate_script_output "cryptsetup luksDump /dev/$part->{name}",
              sub { m/Version:\s+$luks_type.*/s };
        }
    }
}

1;
