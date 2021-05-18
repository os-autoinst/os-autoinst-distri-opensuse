# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
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

use Mojo::JSON 'decode_json';

our @EXPORT = qw(
  str_to_mb
  parted_print
  partition_num_by_start_end
  partition_num_by_type
  free_space
  mountpoint_to_partition
  partition_table
  create_partition remove_partition
  format_partition
  get_partition_size
  get_used_partition_space
  lsblk_command
  validate_lsblk
  get_partition_table_via_blkid);

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

parted_print( dev => '/dev/vda'[, unit => 'GB']);

Print partition  of device B<dev> in unit B<unit>.
By default B<unit> is expressed in MB.

=cut
sub parted_print {
    my (%args) = @_;
    my $dev    = $args{dev};
    my $unit   = $args{unit};
    $unit //= 'MB';

    my $cmd = "parted -s $dev unit $unit print free";
    script_output($cmd);
}

=head2 partition_num_by_start_end

Get partition number by given device partition start and end

=cut
sub partition_num_by_start_end {
    my ($dev, $start, $end) = @_;
    my $output = parted_print(dev => $dev);
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
    my $output = parted_print(dev => $dev);
    if ($output =~ /(\d+)\s+([\d.]+)MB\s+([\d.]+)MB\s+([\d.]+)MB.*?$type/i) {
        return $1;
    }
    else {
        return -1;
    }
}

=head2 free_space

    free_space( dev => '/dev/vda', unit => 'MB');

Using utility C<parted> and passing named arguments B<dev> and B<unit> in which to
perform the operation, get all information (start, end, size) about the bigest free space
Return a hash containing start, end and size

=cut
sub free_space {
    my (%args) = @_;
    my $dev    = $args{dev};
    my $unit   = $args{unit};
    my %space;
    my $output = parted_print(dev => $args{dev}, unit => $args{unit});

    my ($start, $end, $size);
    foreach my $line (split(/\n/, $output)) {
        if ($line =~ /\s*([\d.]+)$unit\s+([\d.]+)$unit\s+([\d.]+)$unit\s*Free Space/) {
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
    my $output = parted_print(dev => $dev);
    my $match;
    if ($output =~ /Partition Table:\s*(\w+)/i) {
        $match = $1;
    }
    return $match;
}

=head2 get_partition_table_via_blkid

    get_partition_table_via_blkid('/dev/vda');

Get partition table information of giving device using blkid
(for example, minimal role does not install parted)

=cut
sub get_partition_table_via_blkid {
    my $dev = shift;
    return (split(/\"/, script_output("blkid $dev")))[-1];
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
    my %space      = free_space(dev => $dev, unit => 'MB');
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

=head2 df_command

Returns the value of the "df -h" output in given column, for a given partition 

  df_command([partition=>$partition , column=> $column])

=cut
sub df_command {
    my $args = shift;
    return script_output("df -h $args->{partition} | awk \'NR==2 {print \$$args->{column}}\'");
}

=head2 get_partition_size

Return the value of the defined partition size

  get_partition_size($partition)

=cut
sub get_partition_size {
    my $partition = shift;
    return df_command({partition => $partition, column => '2'});
}

=head2 get_used_partition_space

Returns the value of used space of the defined partition

  get_used_partition_space($partition)

=cut
sub get_used_partition_space {
    my $partition = shift;
    return df_command({partition => $partition, column => '5'});
}

=head2 lsblk_command

 my $json = lsblk_command(output => $output);

Runs utility C<lsblk> using flag -J to retrieve json and returns
decoded json.

Named argument B<output> specifies a comma-separated list of columns
selected for the output.

=cut

sub lsblk_command {
    my (%args) = @_;
    my $output = $args{output} ? " --output $args{output}" : "";
    my $device = $args{device} ? " $args{device}"          : "";
    decode_json(script_output("lsblk -J$output$device"));
}

=head2 create_lsblk_validation_test_data

 my $validation_test_data = create_lsblk_validation_test_data($dev);

Converts test data to test data adapted for validation using C<lsblk>.

For the device passed converts its test data to corresponding lsblk columns if
available in the mapping of this function.
Returns the following hash ref structure:
    {
      <lsblk_col_name_1> => {
        test_data_name => <test_data_col_name>,
        value          => <value> }
      <lsblk_col_name_2> => {
        ... }
    };

=cut

sub create_lsblk_validation_test_data {
    my $dev          = shift;
    my $columns      = {};
    my %to_lsblk_col = (
        name        => 'name',
        size        => 'size',
        filesystem  => 'fstype',
        mount_point => 'mountpoint');

    my ($col_name, $col_name_test_data, $value);
    for my $k (keys %{$dev}) {
        if ($k eq 'formatting_options') {
            $col_name           = $to_lsblk_col{filesystem};
            $col_name_test_data = 'filesystem';
            $value              = $dev->{formatting_options}{filesystem};
        }
        elsif ($k eq 'mounting_options') {
            $col_name           = $to_lsblk_col{mount_point};
            $col_name_test_data = 'mount_point';
            $value              = $dev->{mounting_options}{mount_point};
            $value              = "[SWAP]" if $value eq 'SWAP';
        }
        else {
            $col_name           = $to_lsblk_col{$k};
            $col_name_test_data = $k;
            $value              = $dev->{$k};
        }

        if ($col_name) {
            $columns = {
                %{$columns}, (
                    $col_name => {
                        test_data_name => $col_name_test_data,
                        value          => $value})};
        }
    }
    return $columns;
}

=head2 validate_lsblk

    $errors .= validate_lsblk(device => $disk, type => 'disk');

Validates test data using C<lsblk> and returns a summary of all errors found.

B<device> represents the device which is used to get output from C<lsblk> command.
Use common structure in test data for partitioning, for example:

disks:
  - name: vda
    table_type: gpt
    allowed_unpartitioned: 0.00GB
    partitions:
      - name: vda1
        formatting_options:
          should_format: 1
          filesystem: xfs
        mounting_options:
          should_mount: 1
          mount_point: /
  ...

B<type> represents the type of device. Valid values: 'disk' and 'part';

Returns string with all found errors.

=cut
sub validate_lsblk {
    my (%args) = @_;
    my $dev    = $args{device};
    my $type   = $args{type};

    my $validation_test_data = create_lsblk_validation_test_data($dev);

    my $blockdev = lsblk_command(
        output => join(',', (keys %{$validation_test_data}, 'type')),
        device => "/dev/$dev->{name}")->{blockdevices}[0];

    my $errors;
    if ($type ne $blockdev->{type}) {
        $errors .= "Wrong type in blockdevice /dev/$dev->{name}. " .
          "Expected: type: $type, got: type: '$blockdev->{type}'\n";
    }

    for my $col (keys %{$validation_test_data}) {
        if ($validation_test_data->{$col}{value} ne $blockdev->{$col}) {
            $errors .= "Wrong $col in blockdevice /dev/$dev->{name}. " .
              "Expected: '$validation_test_data->{$col}{test_data_name}: " .
              "$validation_test_data->{$col}{value}', got: '$col: $blockdev->{$col}'\n";
        }
    }
    return $errors;
}

1;
