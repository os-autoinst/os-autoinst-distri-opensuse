# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Base module for xfstests
# - Including some operation(create/remove/format) to partitions
# - Get free space infomation from storage
# Maintainer: Yong Sun <yosun@suse.com>
package filesystem_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use utils;
use testapi;

our @EXPORT = qw(str_to_mb parted_print partition_num_by_start_end
  partition_num_by_type free_space mountpoint_to_partition
  partition_table create_partition remove_partition format_partition);

=head2 str_to_mb

Format number and unit from KB, MB, GB, TB to MB

=cut
sub str_to_mb {
    my $str = shift;
    if ($str =~ /(\d+(\.\d+)?)K/) {
        return $1 / 1024;
    }
    elsif ($str =~ /(\d+(\.\d+)?)M/) {
        return $1;
    }
    elsif ($str =~ /(\d+(\.\d+)?)G/) {
        return $1 * 1024;
    }
    elsif ($str =~ /(\d+(\.\d+)?)T/) {
        return $1 * 1024 * 1024;
    }
    else {
        return;
    }
}

=head2 parted_print

Print dev partition info by MB

=cut
sub parted_print {
    my $dev = shift;
    my $cmd = "parted -s $dev unit MB print free";
    script_output($cmd);
}

=head2 partition_num_by_start_end

Get partition number by given device partition start and end

=cut
sub partition_num_by_start_end {
    my ($dev, $start, $end) = @_;
    my $output = parted_print($dev);
    my $match;
    if ($output =~ /(\d+)\s+($start)MB\s+($end)MB\s+(\d+\.?\d*)MB/i) {
        $match = $1;
    }
    return $match;
}

=head2 partition_num_by_type

Get the first parition number by given device and partition/FS type. e.g. extended, xfs
Return -1 when not find

=cut
sub partition_num_by_type {
    my ($dev, $type) = @_;
    my $output = parted_print($dev);
    if ($output =~ /(\d+)\s+([\d.]+)MB\s+([\d.]+)MB\s+([\d.]+)MB.*?$type/i) {
        return $1;
    }
    else {
        return -1;
    }
}

=head2 free_space

Get all information (start, end, size) about the bigest free space
Return a hash contain start, end and size

=cut
sub free_space {
    my $dev = shift;
    my %space;
    my $output = parted_print($dev);
    my ($start, $end, $size);
    foreach my $line (split(/\n/, $output)) {
        if ($line =~ /\s*([\d.]+)MB\s+([\d.]+)MB\s+([\d.]+)MB\s*Free Space/) {
            $start = $1;
            $end   = $2;
            $size  = $3;
            if (!exists($space{size}) || $size > $space{size}) {
                $space{start} = $start;
                $space{end}   = $end;
                $space{size}  = $size;
            }
        }
    }
    return %space;
}

=head2 mountpoint_to_partition

Get partition by mountpoint, e.g. give /home get /dev/sda3

=cut
sub mountpoint_to_partition {
    my $mountpoint = shift;
    my $output     = script_output('mount');
    my $match;
    if ($output =~ /(\S+) on $mountpoint type/i) {
        $match = $1;
    }
    else {
        print 'Warning: mountpoint did not match.';
        return $match;
    }
}

=head2 partition_table

Get partition table information by giving device

=cut
sub partition_table {
    my $dev    = shift;
    my $output = parted_print($dev);
    my $match;
    if ($output =~ /Partition Table:\s*(\w+)/i) {
        $match = $1;
    }
    return $match;
}

=head2 create_partition

Create a new partition by giving device, partition type and partition size
part_type (extended|logical|primary)

=cut
sub create_partition {
    my ($dev, $part_type, $size) = @_;
    my ($part_start, $part_end);
    my $part_table       = partition_table($dev);
    my %msdos_part_types = ('extended', 1, 'logical', 1);
    if ($part_table != 'msdos' && exists($msdos_part_types{$part_type})) {
        die 'extended/logical partitions can only be created with msdos partition table!';
    }
    my %space      = free_space($dev);
    my $space_size = int($space{size});
    if ($space_size == 0) {
        die 'No space left in device!';
    }
    if ($size =~ /max/ || $part_type =~ /extended/) {
        $part_start = $space{start};
        $part_end   = $space{end};
    }
    else {
        $part_start = $space{start};
        $part_end   = int($space{start}) + $size;
    }
    my $cmd = "parted -s -a min $dev mkpart $part_type $part_start" . "MB $part_end" . "MB";
    assert_script_run($cmd);
    sleep 1;
    script_run("partprobe $dev");
    my $seq = partition_num_by_start_end($dev, $part_start, $part_end);
    # For NVMe
    if ($dev =~ /\d$/) {
        return $dev . 'p' . $seq;
    }
    else {
        return $dev . $seq;
    }
}

=head2 remove_partition

Remove a partition by given partition name, e.g /dev/sdb5

=cut
sub remove_partition {
    my $part = shift;
    my ($dev, $num);
    if ($part =~ /(.*?)(\d+)/) {
        $dev = $1;
        $num = $2;
    }
    else {
        die "Invalid partition: $part\n";
    }
    assert_script_run("umount -f $part");
    sleep 1;
    assert_script_run("parted -s $dev rm $num");
    sleep 1;
    script_run("partprobe $dev");
}

=head2 format_partition

Format partition to target filesystem

=cut
sub format_partition {
    my ($part, $filesystem) = @_;
    script_run("umount -f $part");
    sleep 1;
    if ($filesystem =~ /ext4/) {
        script_run("mkfs.$filesystem -F $part");
    }
    else {
        script_run("mkfs.$filesystem -f $part");
    }
}

1;
