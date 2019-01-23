# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package xfstests_device;
# Summary:  Device prepare related base class for xfstests_run
# Maintainer: Yong Sun <yosun@suse.com>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use utils;
use testapi qw(is_serial_terminal :DEFAULT);

# Create test partition and scratch partition, and make FS in them
sub dev_create_partition {
    my $self         = shift;
    my $test_fs_type = get_var('TEST_FS_TYPE', '');
    unless ($test_fs_type) {
        $test_fs_type = "xfs";
        print "warning: TEST_FS_TYPE not configured, test defaultly set it to xfs.";
    }
    type_string "df -h\n";
    type_string "parted --script --machine -l 2>&1\n";
    my $cmd               = "parted --script --machine -l 2>&1| awk -F \':\' \'{if(\$5 == \"xfs\") print \$1}\'";
    my $test_partition_id = script_output($cmd, 10);
    my $test_partition    = "/dev/vda" . $test_partition_id;

    # seperate xfs partition(/home) into two same size xfs
    $cmd = "parted --script --machine -l 2>&1| awk -F \':\' \'{if(\$5 == \"xfs\") print \$2}\'";
    my $partition_begin       = script_output($cmd, 10);
    my $extendpartition_begin = $partition_begin;
    $cmd = "parted --script --machine -l 2>&1| awk -F \':\' \'{if(\$5 == \"xfs\") print \$3}\'";
    my $partition_end       = script_output($cmd, 10);
    my $extendpartition_end = $partition_end;
    my $partition_cut_point = $self->get_cut_point($partition_begin, $partition_end, 2);
    assert_script_run("umount " . $test_partition);
    type_string "parted /dev/vda\n";
    type_string "rm " . $test_partition_id . "\n", 5;
    type_string "mkpart logical " . $test_fs_type . " " . $partition_begin . " " . $partition_cut_point . "\n", 5;
    type_string "Yes\n";
    type_string "mkpart logical " . $test_fs_type . " " . $partition_cut_point . " " . $partition_end . "\n", 5;
    #Following line for this: The resulting partition is not properly aligned for best performance.Ignore/Cancel?
    type_string "Yes\n";
    type_string "Ignore\n";
    type_string "quit\n";
    $cmd
      = "parted --script --machine -l 2>&1| awk -F \':\' \'{if(\$2 == \"$extendpartition_begin\" && \$3 != \"$extendpartition_end\" && \$4~/MB|GB/) print \$1}\'";

    # reset test partition number, because sometimes this id changed after mkpart
    $test_partition_id = script_output($cmd, 10);
    $test_partition    = "/dev/vda" . $test_partition_id;

    type_string "parted --script --machine -l\n", 5;
    #workaround bsc#1072549
    type_string "umount /home\n", 5;

    # scratch partition number not always equal to test_partition + 1, so add these two line. poo#31156
    $cmd = "parted --script --machine -l 2>&1| awk -F \':\' \'{if(\$3 == \"$extendpartition_end\" && \$4~/MB|GB/) print \$1}\'";
    my $scratch_partition_id = script_output($cmd, 10);
    my $scratch_partition    = "/dev/vda" . $scratch_partition_id;

    assert_script_run("mkfs." . $test_fs_type . " -f " . $test_partition);
    assert_script_run("mkfs." . $test_fs_type . " -f " . $scratch_partition);

    $self->dev_update_fstab($test_partition, $scratch_partition, $test_fs_type);
    return ($test_partition, $scratch_partition, $test_fs_type);
}

# get_cut_point(begin, end, dev_num): find the suitable cut point between begin and end, and return the first cut point, unit: Mbit
#   e.g. get_cut_point(21.1MB, 33.1MB, 6) will return 23.1
sub get_cut_point {
    my $self = shift;
    my ($begin, $end, $dev_num) = @_;
    print "begin = $begin, end = $end, test and scratch device number = $dev_num\n";
    unless ($dev_num =~ /[2-9]|[1-9]\d+/) {
        die "The setting Device Number is $dev_num. It's not available, or not biger than 1\n";
    }
    if ($begin eq $end) {
        die "No space for new partition, begin and end are same.\n";
    }
    $begin = $self->str_to_mb($begin);
    $end   = $self->str_to_mb($end);
    $begin + (1.0 * ($end - $begin) / $dev_num);
}

# str_to_mb(string): Change string to number, unit: Mbit, e.g: 2GB -> 2000
sub str_to_mb {
    my $self = shift;
    my $str  = shift;
    print "str = $str\n";
    my $result = "";
    if ($str =~ /(\d+(\.\d+)?)kB/) {
        print "result = $1\n";
        $result = $1 / 1024;
    }
    elsif ($str =~ /(\d+(\.\d+)?)MB/) {
        print "result = $1\n";
        $result = $1;
    }
    elsif ($str =~ /(\d+(\.\d+)?)GB/) {
        print "result = $1\n";
        $result = $1 * 1024;
    }
    else {
        die "Input not available in str_to_mb().";
    }
}

# dev_update_fstab(test_partition, scratch_partition, test_fs_type): Add new partition into /etc/fstab, to solve problem when mount them
sub dev_update_fstab {
    my $self = shift;
    my ($test_partition, $scratch_partition, $test_fs_type) = @_;
    assert_script_run("cat /etc/fstab");
    my $cmd       = "blkid " . $test_partition . " 2>&1| awk -F \'\"\' \'{print \$2}\'";
    my $test_uuid = script_output($cmd, 10);
    $cmd = "blkid " . $scratch_partition . " 2>&1| awk -F \'\"\' \'{print \$2}\'";
    my $scratch_uuid = script_output($cmd, 10);
    assert_script_run("sed -i '/home/d' /etc/fstab");
    assert_script_run("sed -i '\$aUUID=$test_uuid /mnt/test " . $test_fs_type . " defaults 1 2' /etc/fstab");
    assert_script_run("sed -i '\$aUUID=$scratch_uuid /mnt/scratch " . $test_fs_type . " defaults 1 2' /etc/fstab");
    assert_script_run("cat /etc/fstab");
}
1;
