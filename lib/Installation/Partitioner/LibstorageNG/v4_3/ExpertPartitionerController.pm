# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Libstorage-NG (version 4.3+)
# Expert Partitioner.
# Libstorage-NG version 4.3 introduces reworked UI which heavily relies on new
# menu widget bar
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController;
use strict;
use warnings;
use parent 'Installation::Partitioner::LibstorageNG::v4::ExpertPartitionerController';
use Installation::Partitioner::LibstorageNG::v4_3::AddLogicalVolumePage;
use Installation::Partitioner::LibstorageNG::v4_3::AddVolumeGroupPage;
use Installation::Partitioner::LibstorageNG::v4_3::ClonePartitionsDialog;
use Installation::Partitioner::LibstorageNG::v4_3::CreatePartitionTablePage;
use Installation::Partitioner::LibstorageNG::v4_3::DeletingCurrentDevicesWarning;
use Installation::Partitioner::LibstorageNG::v4_3::ErrorDialog;
use Installation::Partitioner::LibstorageNG::v4_3::ModifiedDevicesWarning;
use Installation::Partitioner::LibstorageNG::v4_3::SmallForSnapshotsWarning;
use Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerPage;
use Installation::Partitioner::LibstorageNG::v4_3::ResizePage;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{ExpertPartitionerPage}         = Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerPage->new({app => YuiRestClient::get_app()});
    $self->{ClonePartitionsDialog}         = Installation::Partitioner::LibstorageNG::v4_3::ClonePartitionsDialog->new({app => YuiRestClient::get_app()});
    $self->{CreatePartitionTablePage}      = Installation::Partitioner::LibstorageNG::v4_3::CreatePartitionTablePage->new({app => YuiRestClient::get_app()});
    $self->{DeletingCurrentDevicesWarning} = Installation::Partitioner::LibstorageNG::v4_3::DeletingCurrentDevicesWarning->new({app => YuiRestClient::get_app()});
    $self->{ErrorDialog}                   = Installation::Partitioner::LibstorageNG::v4_3::ErrorDialog->new({app => YuiRestClient::get_app()});
    $self->{ModifiedDevicesWarning}        = Installation::Partitioner::LibstorageNG::v4_3::ModifiedDevicesWarning->new({app => YuiRestClient::get_app()});
    $self->{SmallForSnapshotsWarning}      = Installation::Partitioner::LibstorageNG::v4_3::SmallForSnapshotsWarning->new({app => YuiRestClient::get_app()});
    $self->{AddVolumeGroupPage}            = Installation::Partitioner::LibstorageNG::v4_3::AddVolumeGroupPage->new({app => YuiRestClient::get_app()});
    $self->{AddLogicalVolumePage}          = Installation::Partitioner::LibstorageNG::v4_3::AddLogicalVolumePage->new({app => YuiRestClient::get_app()});
    $self->{ResizePage}                    = Installation::Partitioner::LibstorageNG::v4_3::ResizePage->new({app => YuiRestClient::get_app()});

    return $self;
}

sub get_add_volume_group_page {
    my ($self) = @_;
    return $self->{AddVolumeGroupPage};
}

sub get_clone_partition_dialog {
    my ($self) = @_;
    return $self->{ClonePartitionsDialog};
}

sub get_create_new_partition_table_page {
    my ($self) = @_;
    return $self->{CreatePartitionTablePage};
}

sub get_deleting_current_devices_warning {
    my ($self) = @_;
    return $self->{DeletingCurrentDevicesWarning};
}

sub get_small_for_snapshots_warning {
    my ($self) = @_;
    return $self->{SmallForSnapshotsWarning};
}

sub get_add_logical_volume_page {
    my ($self) = @_;
    return $self->{AddLogicalVolumePage};
}

sub get_resize_page {
    my ($self) = @_;
    return $self->{ResizePage};
}

sub get_error_dialog {
    my ($self) = @_;
    return $self->{ErrorDialog};
}

sub get_modified_devices_warning {
    my ($self) = @_;
    return $self->{ModifiedDevicesWarning};
}

sub add_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_disk($args->{disk}) if $args->{disk};
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->_add_partition($args->{partition});
}

sub clone_partition_table {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->open_clone_partition_dialog($args->{disk});
    if ($args->{target_disks}) {
        $self->get_clone_partition_dialog()->select_disks(@{$args->{target_disks}});
    } else {
        $self->get_clone_partition_dialog()->select_all_disks();
    }
    $self->get_clone_partition_dialog()->press_ok();
}

sub cancel_changes {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->press_cancel_button();
    if ($args->{accept_modified_devices_warning}) {
        $self->get_modified_devices_warning()->press_yes();
    }
}

sub add_raid_partition {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_raid();
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->_add_partition($args);
}

sub add_raid {
    my ($self, $args) = @_;
    my $raid_level            = $args->{raid_level};
    my $device_selection_step = $args->{device_selection_step};
    $self->get_expert_partitioner_page()->select_raid();
    $self->get_expert_partitioner_page()->press_add_raid_button();
    $self->get_raid_type_page()->set_raid_level($raid_level);
    $self->get_raid_type_page()->select_devices_from_list($device_selection_step);
    $self->get_raid_type_page()->press_next();
    $self->get_raid_options_page()->press_next();
    $self->add_raid_partition($args->{partition});
}

sub create_new_partition_table {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_disk($args->{name});
    $self->get_expert_partitioner_page()->select_create_partition_table();
    if ($args->{accept_deleting_current_devices_warning}) {
        $self->get_deleting_current_devices_warning()->press_yes();
    }
    $self->get_create_new_partition_table_page()->press_next();
}

sub add_volume_group {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_lvm();
    $self->get_expert_partitioner_page()->press_add_volume_group_button();
    $self->get_add_volume_group_page()->set_volume_group_name($args->{name});
    foreach my $device (@{$args->{devices}}) {
        $self->get_add_volume_group_page()->select_available_device($device);
    }
    $self->get_add_volume_group_page()->press_add_button();
    $self->get_add_volume_group_page()->press_next_button();
}

sub add_logical_volume {
    my ($self, $args) = @_;
    my $lv = $args->{logical_volume};
    $self->get_expert_partitioner_page()->select_volume_group($args->{volume_group});
    $self->get_expert_partitioner_page()->press_add_logical_volume_button();
    $self->get_add_logical_volume_page()->set_logical_volume_name($lv->{name});
    $self->get_add_logical_volume_page()->set_logical_volume_type($lv->{type}) if $lv->{type};
    $self->get_add_logical_volume_page()->press_next_button();
    $self->get_add_logical_volume_page()->set_custom_size($lv->{size}) if $lv->{size};
    $self->get_add_logical_volume_page()->press_next_button();
    unless ($lv->{type} eq 'thin_pool') {
        $self->get_add_logical_volume_page()->select_role($lv->{role});
        $self->get_add_logical_volume_page()->press_next_button();
        $self->_finish_partition_creation;
    }
}

sub setup_raid {
    my ($self, $args) = @_;
    # Create partitions with the data from yaml scheduling file on first disk
    my @disks      = @{$args->{disks}};
    my $first_disk = $disks[0];
    foreach my $partition (@{$first_disk->{partitions}}) {
        $self->add_partition_on_gpt_disk({disk => $first_disk->{name}, partition => $partition});
    }
    # Clone partition table from first disk to all other disks
    my @target_disks = map { $_->{name} } @disks[1 .. $#disks];
    $self->clone_partition_table({disk => $first_disk->{name}, target_disks => \@target_disks});
    # Create RAID partitions with the data from yaml scheduling file
    foreach my $md (@{$args->{mds}}) {
        $self->add_raid($md);
    }
}

sub setup_lvm {
    my ($self, $args) = @_;

    foreach my $vg (@{$args->{volume_groups}}) {
        $self->add_volume_group($vg);
        foreach my $lv (@{$vg->{logical_volumes}}) {
            $self->add_logical_volume({
                    volume_group   => $vg->{name},
                    logical_volume => $lv
            });
        }
    }
}

sub resize_partition {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk_partition({disk => $args->{disk}, partition => $part->{name}});
    $self->get_expert_partitioner_page()->open_resize_device();
    $self->get_resize_page()->set_custom_size($part->{size});
    $self->get_resize_page()->press_next();
}

sub resize_logical_volume {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_logical_volume({
            volume_group   => $args->{volume_group},
            logical_volume => $args->{logical_volume}
    });
    $self->get_expert_partitioner_page()->open_resize_device();
    $self->get_resize_page()->set_custom_size($args->{size});
    $self->get_resize_page()->press_next();
}

sub edit_partition_on_gpt_disk {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk_partition({disk => $args->{disk}, partition => $part->{name}});
    $self->get_expert_partitioner_page()->press_edit_partition_button();
    $self->get_edit_formatting_options_page()->select_format_device_radiobutton($part->{formatting_options}->{skip});
    $self->get_edit_formatting_options_page()->select_filesystem($part->{formatting_options}->{filesystem}, $part->{formatting_options}->{skip});
    $self->get_edit_formatting_options_page()->select_mount_device_radiobutton();
    $self->get_edit_formatting_options_page()->fill_in_mount_point_field($part->{mounting_options}->{mount_point});
    $self->get_edit_formatting_options_page()->press_next();
}

sub confirm_error_dialog {
    my ($self) = @_;
    $self->get_error_dialog()->press_ok();
}

sub get_error_dialog_text {
    my ($self) = @_;
    $self->get_error_dialog()->text();
}

sub edit_partition_encrypt {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_disk_partition({disk => $args->{disk}, partition => $args->{partition}});
    $self->get_expert_partitioner_page()->press_edit_partition_button();
    $self->get_edit_formatting_options_page()->check_encrypt_device_checkbox();
    $self->get_edit_formatting_options_page()->press_next();
    $self->set_encryption_password();
}

1;
