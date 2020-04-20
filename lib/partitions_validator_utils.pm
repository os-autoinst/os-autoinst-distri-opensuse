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
our @EXPORT = qw(
  validate_partition_table
  validate_partition_creation
  validate_filesystem
  validate_read_write
  validate_unpartitioned_space);

sub validate_partition_table {
    my $args = shift;
    return if check_var('BACKEND', 's390x');    # blkid output does not show partition table for dasd
    record_info("Check $args->{table_type}", "Verify if partition table type is $args->{table_type}");
    my $table_type = (split(/\"/, script_output("blkid $args->{device}")))[-1];    # last element of output eg "gpt"
    my $converter  = {msdos => 'dos'};
    my $expected   = $args->{table_type};
    $expected = $converter->{$expected} if (exists $converter->{$expected});
    assert_equals($expected, $table_type, "Partition table type does not correspond to the expected one.");
}

sub validate_partition_creation {
    my $args = shift;
    record_info("Check $args->{mount_point}", "Verify that partition $args->{mount_point} was created.");
    my @lsblk_output = split(/\n/, script_output("lsblk -n"));
    my $check;
    foreach (@lsblk_output) {
        if ($_ =~ /(?<check>\Q$args->{mount_point}\E\s*\Z)/) {
            $check = $+{check};
            last;
        }
    }
    die "The $args->{mount_point} partition was not created." if (!$check);
}

sub validate_filesystem {
    my $args = shift;
    record_info("Check filesystem", "Verify that $args->{mount_point} partition filesystem is $args->{fs_type}");
    my @df_output = split(/\n/, script_output("df -T $args->{mount_point}"));
    my $type      = ((split(/\s*\s/, $df_output[1])))[1];
    assert_equals($args->{fs_type}, $type, "Filesystem type does not correspond to the expected one.");
}

sub validate_read_write {
    my $args = shift;
    assert_script_run("echo Hello > $args->{mount_point}/emptyfile", fail_message => 'Failure while writing in ' . $args->{mount_point});
    assert_script_run("grep Hello $args->{mount_point}/emptyfile",   fail_message => 'Failure while reading from ' . $args->{mount_point});
}

sub validate_unpartitioned_space {
    my $args = shift;
    record_info("Check $args->{disk} partitioning", "Verify that the '$args->{disk}' does not have unpartitioned disk space.");
    my $parted_output = script_output("parted \/dev\/$args->{disk} unit GB print free");
    foreach (split(/\n/, $parted_output)) {
        if ($_ =~ /(?<unpartitioned>(\S+))\s* Free Space/) {
            die "There is $+{unpartitioned} unpartitioned disk space." if ($+{unpartitioned} gt $args->{allowed_unpartitioned});
        }
    }
}

1;
