# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validation module to check File system on partition(s).
# Requires 'test_data->{file_system}' to be specified in yaml scheduling file,
# so that it allows to check the File system on any amount of partitions
# by iterating over the hash.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';
use partitions_validator_utils 'validate_partition_table';

sub run {
    my $test_data            = get_test_suite_data();
    my $partitions           = $test_data->{file_system};
    my $encrypted_partitions = $test_data->{encrypted_filesystem};

    select_console 'root-console';

    my $partitioning = script_output "lsblk -l";
    record_info "lsblk", "$partitioning";
    validate_partition_table({device => "/dev/$test_data->{device}", table_type => $test_data->{table_type}});

    if (defined $partitions) {
        foreach (keys %{$partitions}) {
            record_info("Check fs $_", "Verify the '$_' partition filesystem is '$partitions->{$_}'");
            my $fstype = script_output("df -PT $_ | grep -v \"Filesystem\" | awk '{print \$2}'");
            assert_equals($partitions->{$_}, $fstype,
                "File system on '$_' partition does not correspond to the expected one");
        }
    }

    if (defined $encrypted_partitions) {
        foreach (@{$encrypted_partitions}) {
            record_info("Check size", "Verify encrypted partition size");
            assert_script_run("lsblk -n /dev/$_->{partition} | grep '$_->{size}'",
                fail_message => "Encrypted partition was not resized during installation " .
                  "from " . get_var('HDDSIZEGB') . " GB (check qemu parameters) " .
                  "to fixed size $_->{size} (check AutoYaST profile)");
            record_info("Check luks2", "Check partition is still luks2 (taking into account that is not mounted)");
            my $luks_type = $_->{luks_type};
            validate_script_output "cryptsetup luksDump /dev/$_->{partition}",
              sub { m/Version:\s+$luks_type.*/s };
        }
    }
}

1;
