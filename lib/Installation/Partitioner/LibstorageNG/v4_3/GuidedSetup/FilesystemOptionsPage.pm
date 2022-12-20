# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces methods to handle Filesystem Options page
#          in Guided Partitioning.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::FilesystemOptionsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{lbl_settings_root_part} = $self->{app}->label({label => 'Settings for the Root Partition'});
    $self->{cmb_root_fs_type} = $self->{app}->combobox({id => '"vol_0_fs_type"'});
    $self->{chb_separate_home} = $self->{app}->checkbox({id => '"vol_1_proposed"'});
    return $self;
}

sub unselect_propose_separate_home {
    my ($self) = @_;
    $self->{chb_separate_home}->uncheck();
}

sub select_root_filesystem {
    my ($self, $fs) = @_;
    my %filesystems = (
        ext2 => 'Ext2',
        ext3 => 'Ext3',
        ext4 => 'Ext4',
        btrfs => 'Btrfs',
        xfs => 'XFS');
    my $root_fs = $filesystems{$fs};
    return $self->{cmb_root_fs_type}->select($root_fs) if $root_fs;
    die "Wrong test data provided when selecting root file system: $fs \n" .
      'Available options: ' . join(' ', sort keys %filesystems);
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_root_fs_type}->exist();
}

1;
