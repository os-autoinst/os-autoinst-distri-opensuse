# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package partitions_validator_utils;
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use testapi;
use Test::Assert ':all';
use Exporter 'import';
our @EXPORT = 'validate_partition_table';

sub validate_partition_table {
    my $args = shift;
    return if check_var('BACKEND', 's390x');    # blkid output does not show partition table for dasd
    record_info("Check $args->{table_type}", "Verify if partition table type is $args->{table_type}");
    my $table_type = (split(/\"/, script_output("blkid $args->{device}")))[-1];    # last element of output eg "gpt"
    assert_equals($args->{table_type}, $table_type, "Partition table type does not correspond to the expected one.");
}

1;
