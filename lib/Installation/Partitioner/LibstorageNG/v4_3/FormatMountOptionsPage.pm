# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles page for common formatting and mounting options
# when adding a partition using Expert Partitioner.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::FormatMountOptionsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;
use YuiRestClient::Wait;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{cb_filesystem} = $self->{app}->combobox({id => '"Y2Partitioner::Widgets::BlkDeviceFilesystem"'});
    $self->{cb_enable_snapshots} = $self->{app}->checkbox({id => '"Y2Partitioner::Widgets::Snapshots"'});
    $self->{rb_format_device} = $self->{app}->radiobutton({id => 'format_device'});
    $self->{rb_no_format_device} = $self->{app}->radiobutton({id => 'no_format_device'});
    $self->{rb_mount_device} = $self->{app}->radiobutton({id => 'mount_device'});
    $self->{cb_mount_point} = $self->{app}->combobox({id => '"Y2Partitioner::Widgets::MountPoint"'});
    $self->{rb_no_mount_device} = $self->{app}->radiobutton({id => 'dont_mount_device'});
    $self->{cb_encrypt} = $self->{app}->checkbox({id => '"Y2Partitioner::Widgets::EncryptBlkDevice"'});
    $self->{btn_fstab_options} = $self->{app}->button({id => '"Y2Partitioner::Widgets::FstabOptionsButton"'});
    return $self;
}

sub enter_formatting_options {
    my ($self, $formatting_options) = @_;
    my $should_format = $formatting_options->{should_format};
    my $filesystem = $formatting_options->{filesystem};
    my $enable_snapshots = $formatting_options->{enable_snapshots};
    $self->select_format() if $should_format == 1;
    $self->select_not_format() if $should_format == 0;
    $self->select_filesystem($filesystem) if $filesystem;
    $self->enable_snapshots() if $enable_snapshots;
}

sub select_format {
    my ($self) = @_;
    # Workaround with selecting 'Format Device' radio button until 'Filesystem' combobox is enabled.
    # Needed to resolve sporadic issue on aarch64, that most likely happens due to workers slowness: poo#88524
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{rb_format_device}->select();
            return $self->{cb_filesystem}->is_enabled();
    });
}

sub select_not_format {
    my ($self) = @_;
    return $self->{rb_no_format_device}->select();
}

sub select_filesystem {
    my ($self, $filesystem) = @_;
    my %filesystems = (
        ext2 => 'Ext2',
        ext3 => 'Ext3',
        ext4 => 'Ext4',
        btrfs => 'Btrfs',
        fat => 'FAT',
        xfs => 'XFS',
        swap => 'Swap',
        udf => 'UDF'
    );
    return $self->{cb_filesystem}->select($filesystems{$filesystem}) if $filesystems{$filesystem};
    die "Wrong test data provided when selecting filesystem.\n" .
      "Avalaible options: ext2, ext3, ext4, btrfs, fat, xfs, swap, udf";
}

sub enable_snapshots {
    my ($self) = @_;
    $self->{cb_enable_snapshots}->check();
}

sub encrypt_device {
    my ($self, $encrypt) = @_;
    $self->{cb_encrypt}->check();
}

sub enter_mounting_options {
    my ($self, $mounting_options) = @_;
    my $should_mount = $mounting_options->{should_mount};
    my $mount_point = $mounting_options->{mount_point};
    $self->select_mount() if $should_mount == 1;
    $self->select_not_mount() if $should_mount == 0;
    $self->set_mount_point($mount_point) if $mount_point;
}

sub select_mount {
    my ($self) = @_;
    return $self->{rb_mount_device}->select();
}

sub select_not_mount {
    my ($self) = @_;
    return $self->{rb_no_mount_device}->select();
}

sub set_mount_point {
    my ($self, $mount_point) = @_;
    my @items = $self->{cb_mount_point}->items();
    if (grep { $mount_point eq $_ } @items) {
        return $self->select_mount_point($mount_point);
    }
    else {
        return $self->enter_mount_point($mount_point);
    }
}

sub select_mount_point {
    my ($self, $mount_point) = @_;
    return $self->{cb_mount_point}->select($mount_point);
}

sub enter_mount_point {
    my ($self, $mount_point) = @_;
    return $self->{cb_mount_point}->set($mount_point);
}

sub press_fstab_options {
    my ($self) = @_;
    return $self->{btn_fstab_options}->click();
}

1;
