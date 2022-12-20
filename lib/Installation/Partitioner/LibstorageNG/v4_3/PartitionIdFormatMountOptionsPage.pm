# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Page in Expert Partitioner for formatting/mounting options
# for adding a partition when Partition Id is available.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::PartitionIdFormatMountOptionsPage;
use strict;
use warnings;
use parent 'Installation::Partitioner::LibstorageNG::v4_3::FormatMountOptionsPage';

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self) = shift;
    $self->SUPER::init();
    $self->{cmb_partition_id} = $self->{app}->combobox({id => '"Y2Partitioner::Widgets::PartitionIdComboBox"'});
    return $self;
}

sub select_partition_id {
    my ($self, $partition_id) = @_;
    my %partition_ids = (
        linux => 'Linux',
        'linux-swap' => 'Linux Swap',
        'linux-lvm' => 'Linux LVM',
        'linux-raid' => 'Linux RAID',
        efi => 'EFI System Partition',
        'bios-boot' => 'BIOS Boot Partition',
        'prep-boot' => 'PReP Boot Partition',
        'windows-data' => 'Windows Data Partition',
        'microsoft-reserved' => 'Microsoft Reserved Partition',
        'intel-rst' => 'Intel RST'
    );
    return $self->{cmb_partition_id}->select($partition_ids{$partition_id}) if $partition_ids{$partition_id};
    die "Wrong test data provided when selecting partition id.\n" .
      "Available options: linux, linux-swap, linux-lvm, linux-raid, efi, bios-boot, prep-boot, " .
      "windows-data, microsoft-reserved, intel-rst";
}

1;
