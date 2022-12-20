# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
use Installation::Partitioner::LibstorageNG::v4_3::MsdosPartitionTypePage;
use Installation::Partitioner::LibstorageNG::v4_3::SummaryPage;
use Installation::Partitioner::LibstorageNG::v4_3::NewPartitionSizePage;
use Installation::Partitioner::LibstorageNG::v4_3::RolePage;
use Installation::Partitioner::LibstorageNG::v4_3::PartitionIdFormatMountOptionsPage;
use Installation::Partitioner::LibstorageNG::v4_3::EncryptPartitionPage;
use Installation::Partitioner::LibstorageNG::v4_3::FormatMountOptionsPage;
use Installation::Partitioner::LibstorageNG::v4_3::LogicalVolumeSizePage;
use Installation::Partitioner::LibstorageNG::v4_3::RaidTypePage;
use Installation::Partitioner::LibstorageNG::v4_3::RaidOptionsPage;
use Installation::Partitioner::LibstorageNG::v4_3::FstabOptionsPage;
use Installation::Popups::YesNoPopup;
use Installation::Popups::OKPopup;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{ExpertPartitionerPage} = Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerPage->new({app => YuiRestClient::get_app()});
    $self->{ClonePartitionsDialog} = Installation::Partitioner::LibstorageNG::v4_3::ClonePartitionsDialog->new({app => YuiRestClient::get_app()});
    $self->{CreatePartitionTablePage} = Installation::Partitioner::LibstorageNG::v4_3::CreatePartitionTablePage->new({app => YuiRestClient::get_app()});
    $self->{DeletingCurrentDevicesWarning} = Installation::Partitioner::LibstorageNG::v4_3::DeletingCurrentDevicesWarning->new({app => YuiRestClient::get_app()});
    $self->{ErrorDialog} = Installation::Partitioner::LibstorageNG::v4_3::ErrorDialog->new({app => YuiRestClient::get_app()});
    $self->{ModifiedDevicesWarning} = Installation::Partitioner::LibstorageNG::v4_3::ModifiedDevicesWarning->new({app => YuiRestClient::get_app()});
    $self->{SmallForSnapshotsWarning} = Installation::Partitioner::LibstorageNG::v4_3::SmallForSnapshotsWarning->new({app => YuiRestClient::get_app()});
    $self->{AddVolumeGroupPage} = Installation::Partitioner::LibstorageNG::v4_3::AddVolumeGroupPage->new({app => YuiRestClient::get_app()});
    $self->{AddLogicalVolumePage} = Installation::Partitioner::LibstorageNG::v4_3::AddLogicalVolumePage->new({app => YuiRestClient::get_app()});
    $self->{ResizePage} = Installation::Partitioner::LibstorageNG::v4_3::ResizePage->new({app => YuiRestClient::get_app()});
    $self->{MsdosPartitionTypePage} = Installation::Partitioner::LibstorageNG::v4_3::MsdosPartitionTypePage->new({app => YuiRestClient::get_app()});
    $self->{SummaryPage} = Installation::Partitioner::LibstorageNG::v4_3::SummaryPage->new({app => YuiRestClient::get_app()});
    $self->{NewPartitionSizePage} = Installation::Partitioner::LibstorageNG::v4_3::NewPartitionSizePage->new({app => YuiRestClient::get_app()});
    $self->{RolePage} = Installation::Partitioner::LibstorageNG::v4_3::RolePage->new({app => YuiRestClient::get_app()});
    $self->{PartitionIdFormatMountOptionsPage} = Installation::Partitioner::LibstorageNG::v4_3::PartitionIdFormatMountOptionsPage->new({app => YuiRestClient::get_app()});
    $self->{EncryptPartitionPage} = Installation::Partitioner::LibstorageNG::v4_3::EncryptPartitionPage->new({app => YuiRestClient::get_app()});
    $self->{FormatMountOptionsPage} = Installation::Partitioner::LibstorageNG::v4_3::FormatMountOptionsPage->new({app => YuiRestClient::get_app()});
    $self->{LogicalVolumeSizePage} = Installation::Partitioner::LibstorageNG::v4_3::LogicalVolumeSizePage->new({app => YuiRestClient::get_app()});
    $self->{RaidTypePage} = Installation::Partitioner::LibstorageNG::v4_3::RaidTypePage->new({app => YuiRestClient::get_app()});
    $self->{RaidOptionsPage} = Installation::Partitioner::LibstorageNG::v4_3::RaidOptionsPage->new({app => YuiRestClient::get_app()});
    $self->{FstabOptionsPage} = Installation::Partitioner::LibstorageNG::v4_3::FstabOptionsPage->new({app => YuiRestClient::get_app()});

    $self->{YesNoPopup} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    $self->{OKPopup} = Installation::Popups::OKPopup->new({app => YuiRestClient::get_app()});
    $self->{OnlyUseIfFamiliarWarning} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    $self->{DeletePartitionWarning} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    $self->{DeleteVolumeGroupWarning} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_msdos_partition_type_page {
    my ($self) = @_;
    return $self->{MsdosPartitionTypePage};
}

sub get_add_volume_group_page {
    my ($self) = @_;
    return $self->{AddVolumeGroupPage};
}

sub get_expert_partitioner_page {
    my ($self) = @_;
    $self->{ExpertPartitionerPage}->is_shown();
    return $self->{ExpertPartitionerPage};
}

sub get_clone_partition_dialog {
    my ($self) = @_;
    return $self->{ClonePartitionsDialog};
}

sub get_only_use_if_familiar_warning {
    my ($self) = @_;
    if ($self->{OnlyUseIfFamiliarWarning}->text() !~
        /Only use this program if you are familiar with partitioning hard disks/) {
        die "Only use if familiar warning is not displayed";
    }
    return $self->{OnlyUseIfFamiliarWarning};
}

sub get_delete_partition_warning {
    my ($self, $part_name) = @_;
    if ($self->{DeletePartitionWarning}->text() !~
        /Really delete \/dev\/$part_name?/) {
        die "Delete partition warning is not displayed";
    }
    return $self->{DeletePartitionWarning};
}

sub get_delete_volume_group_warning {
    my ($self, $vg) = @_;
    if ($self->{DeleteVolumeGroupWarning}->text() !~
        /The volume group \"$vg\" contains at least one logical volume/) {
        die "Delete volume warning is not displayed";
    }
    return $self->{DeleteVolumeGroupWarning};
}

sub get_yes_no_popup {
    my ($self) = @_;
    return $self->{YesNoPopup};
}

sub get_ok_popup {
    my ($self) = @_;
    return $self->{OKPopup};
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

sub get_summary_page {
    my ($self) = @_;
    return $self->{SummaryPage};
}

sub get_new_partition_size_page {
    my ($self) = @_;
    return $self->{NewPartitionSizePage};
}

sub get_role_page {
    my ($self) = @_;
    return $self->{RolePage};
}

sub get_partition_id_format_mount_options_page {
    my ($self) = @_;
    return $self->{PartitionIdFormatMountOptionsPage};
}

sub get_encrypt_partition_page {
    my ($self) = @_;
    return $self->{EncryptPartitionPage};
}

sub get_format_mount_options_page {
    my ($self) = @_;
    return $self->{FormatMountOptionsPage};
}

sub get_logical_volume_size_page {
    my ($self) = @_;
    return $self->{LogicalVolumeSizePage};
}

sub get_raid_type_page {
    my ($self) = @_;
    return $self->{RaidTypePage};
}

sub get_raid_options_page {
    my ($self) = @_;
    return $self->{RaidOptionsPage};
}

sub get_fstab_options_page {
    my ($self) = @_;
    return $self->{FstabOptionsPage};
}

sub add_partition {
    my ($self, $args) = @_;
    my $table_type = $args->{table_type} // '';
    return $self->add_partition_msdos($args) if $table_type eq 'msdos';
    return $self->add_partition_gpt($args);
}

# alias function to not break back-compatibility in test scenarios
sub add_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->add_partition_gpt($args);
}

sub add_partition_gpt {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    return $self->add_partition_gpt_encrypted($args) if $part->{encrypt_device};
    return $self->add_partition_gpt_non_encrypted($args);
}

sub add_partition_gpt_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_new_partition_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->encrypt_device($part->{encrypt});
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
    $self->get_encrypt_partition_page()->set_encryption();
}

sub add_partition_gpt_non_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_new_partition_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_fstab_options_page()->edit_fstab_options($part->{fstab_options}) if $part->{fstab_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
}

sub add_partition_msdos {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    return $self->add_partition_msdos_encrypted($args) if $part->{encrypt_device};
    return $self->add_partition_msdos_non_encrypted($args);
}

sub add_partition_msdos_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_msdos_partition_type_page()->set_type($part->{partition_type});
    $self->get_new_partition_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->encrypt_device($part->{encrypt});
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
    $self->get_encrypt_partition_page()->set_encryption();
}

sub add_partition_msdos_non_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_msdos_partition_type_page()->set_type($part->{partition_type});
    $self->get_new_partition_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
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

sub add_raid {
    my ($self, $args) = @_;
    my $raid_level = $args->{raid_level};
    my $device_selection_step = $args->{device_selection_step};
    my $chunk_size = $args->{chunk_size};
    $self->get_expert_partitioner_page()->select_raid();
    $self->get_expert_partitioner_page()->press_add_raid_button();
    $self->get_raid_type_page()->set_raid_level($raid_level);
    foreach my $device (@{$args->{devices}}) {
        $self->get_raid_type_page()->add_device($device);
    }
    $self->get_raid_type_page()->press_next();
    $self->get_raid_options_page()->select_chunk_size($chunk_size) if $chunk_size;
    $self->get_raid_options_page()->press_next();
    $self->add_raid_partition($args->{partition});
}

sub add_raid_partition {
    my ($self, $part) = @_;
    return $self->add_raid_partition_encrypted($part) if $part->{encrypt_device};
    return $self->add_raid_partition_non_encrypted($part);
}

sub add_raid_partition_non_encrypted {
    my ($self, $part) = @_;
    $self->get_expert_partitioner_page()->select_raid();
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_new_partition_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
}

sub add_raid_partition_encrypted {
    my ($self, $part) = @_;
    $self->get_expert_partitioner_page()->select_raid();
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_new_partition_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->encrypt_device($part->{encrypt});
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
    $self->get_encrypt_partition_page()->set_encryption();
}

sub create_new_partition_table {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_disk($args->{name});
    $self->get_expert_partitioner_page()->select_create_partition_table();
    if ($args->{accept_deleting_current_devices_warning}) {
        $self->get_deleting_current_devices_warning()->press_yes();
    }
    $self->get_create_new_partition_table_page()->select_partition_table_type($args->{table_type});
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
    $self->get_add_volume_group_page()->press_next();
}

sub delete_volume_group {
    my ($self, $vg) = @_;
    $self->get_expert_partitioner_page()->select_volume_group($vg);
    $self->get_expert_partitioner_page()->press_delete_volume_group_button();
    $self->get_delete_volume_group_warning($vg)->press_yes();
}

sub add_logical_volume {
    my ($self, $args) = @_;
    my $type = $args->{logical_volume}->{type} // '';
    return $self->add_logical_volume_thin_pool($args) if $type eq 'thin-pool';
    return $self->add_logical_volume_thin_volume($args) if $type eq 'thin-volume';
    return $self->add_logical_volume_normal($args);
}

sub add_logical_volume_normal {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    return $self->add_logical_volume_normal_encrypted($args) if $part->{encrypt_device};
    return $self->add_logical_volume_normal_non_encrypted($args);
}

sub add_logical_volume_normal_non_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    $self->get_expert_partitioner_page()->select_volume_group($args->{volume_group});
    $self->get_expert_partitioner_page()->press_add_logical_volume_button();
    $self->get_add_logical_volume_page()->enter_name($part->{name});
    $self->get_add_logical_volume_page()->press_next();
    $self->get_logical_volume_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_format_mount_options_page()->press_next();
}

sub add_logical_volume_normal_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    $self->get_expert_partitioner_page()->select_volume_group($args->{volume_group});
    $self->get_expert_partitioner_page()->press_add_logical_volume_button();
    $self->get_add_logical_volume_page()->enter_name($part->{name});
    $self->get_add_logical_volume_page()->press_next();
    $self->get_logical_volume_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_format_mount_options_page()->encrypt_device($part->{encrypt});
    $self->get_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_format_mount_options_page()->press_next();
    $self->get_encrypt_partition_page()->set_encryption();
}

sub add_logical_volume_thin_pool {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    $self->get_expert_partitioner_page()->select_volume_group($args->{volume_group});
    $self->get_expert_partitioner_page()->press_add_logical_volume_button();
    $self->get_add_logical_volume_page()->enter_name($part->{name});
    $self->get_add_logical_volume_page()->select_type($part->{type});
    $self->get_add_logical_volume_page()->press_next();
    $self->get_logical_volume_size_page()->set_custom_size($part->{size});
}

sub add_logical_volume_thin_volume {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    return $self->add_logical_volume_thin_volume_encrypted($args) if $part->{encrypt_device};
    return $self->add_logical_volume_thin_volume_non_encrypted($args);
}

sub add_logical_volume_thin_volume_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    $self->get_expert_partitioner_page()->select_volume_group($args->{volume_group});
    $self->get_expert_partitioner_page()->press_add_logical_volume_button();
    $self->get_add_logical_volume_page()->enter_name($part->{name});
    $self->get_add_logical_volume_page()->select_type($part->{type});
    $self->get_add_logical_volume_page()->press_next();
    $self->get_logical_volume_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_format_mount_options_page()->encrypt_device($part->{encrypt});
    $self->get_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_format_mount_options_page()->press_next();
    $self->get_encrypt_partition_page()->set_encryption();
}

sub add_logical_volume_thin_volume_non_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    $self->get_expert_partitioner_page()->select_volume_group($args->{volume_group});
    $self->get_expert_partitioner_page()->press_add_logical_volume_button();
    $self->get_add_logical_volume_page()->enter_name($part->{name});
    $self->get_add_logical_volume_page()->select_type($part->{type});
    $self->get_add_logical_volume_page()->press_next();
    $self->get_logical_volume_size_page()->set_custom_size($part->{size});
    $self->get_role_page()->set_role($part->{role});
    $self->get_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_format_mount_options_page()->press_next();
}

sub setup_raid {
    my ($self, $args) = @_;
    # Create partitions with the data from yaml scheduling file on first disk
    my @disks = @{$args->{disks}};
    my $first_disk = $disks[0];
    foreach my $partition (@{$first_disk->{partitions}}) {
        $self->add_partition_gpt({disk => $first_disk->{name}, partition => $partition});
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
        foreach my $part (@{$vg->{logical_volumes}}) {
            $self->add_logical_volume({
                    volume_group => $vg->{name},
                    logical_volume => $part
            });
        }
    }
}

sub resize_partition {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk_partition({
            disk => $args->{disk},
            partition => $part->{name}});
    $self->get_expert_partitioner_page()->open_resize_device();
    $self->get_resize_page()->set_custom_size($part->{size});
}

sub delete_partition {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk_partition({disk => $args->{disk}, partition => $part->{name}});
    $self->get_expert_partitioner_page()->press_delete_partition_button();
    $self->get_delete_partition_warning($part->{name})->press_yes();
}

sub resize_logical_volume {
    my ($self, $args) = @_;
    my $part = $args->{logical_volume};
    $self->get_expert_partitioner_page()->select_logical_volume({
            volume_group => $args->{volume_group},
            logical_volume => $part->{name}
    });
    $self->get_expert_partitioner_page()->open_resize_device();
    $self->get_resize_page()->set_custom_size($part->{size});
}

sub edit_partition_gpt {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    return $self->edit_partition_gpt_encrypted($args) if $part->{encrypt_device};
    return $self->edit_partition_gpt_non_encrypted($args);
}

sub edit_partition_gpt_non_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk_partition({disk => $args->{disk}, partition => $part->{name}});
    $self->get_expert_partitioner_page()->press_edit_partition_button();
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
}

sub edit_partition_gpt_encrypted {
    my ($self, $args) = @_;
    my $part = $args->{partition};
    $self->get_expert_partitioner_page()->select_disk_partition({disk => $args->{disk}, partition => $part->{name}});
    $self->get_expert_partitioner_page()->press_edit_partition_button();
    $self->get_partition_id_format_mount_options_page()->enter_formatting_options($part->{formatting_options}) if $part->{formatting_options};
    $self->get_partition_id_format_mount_options_page()->select_partition_id($part->{id}) if $part->{id};
    $self->get_partition_id_format_mount_options_page()->encrypt_device($part->{encrypt});
    $self->get_partition_id_format_mount_options_page()->enter_mounting_options($part->{mounting_options}) if $part->{mounting_options};
    $self->get_partition_id_format_mount_options_page()->press_next();
    $self->get_encrypt_partition_page()->set_encryption();
}

sub confirm_error_dialog {
    my ($self) = @_;
    $self->get_error_dialog()->press_ok();
}

sub get_error_dialog_text {
    my ($self) = @_;
    $self->get_error_dialog()->text();
}

sub get_yes_no_popup_text {
    my ($self) = @_;
    $self->get_yes_no_popup()->text();
}

sub get_ok_popup_text {
    my ($self) = @_;
    $self->get_ok_popup()->text();
}

sub confirm_warning {
    my ($self) = @_;
    $self->get_yes_no_popup()->press_yes();
}

sub decline_warning {
    my ($self) = @_;
    $self->get_yes_no_popup()->press_no();
}

sub show_summary_and_accept_changes {
    my ($self) = @_;
    $self->get_expert_partitioner_page()->press_next();
    $self->get_summary_page()->press_next();
}

sub confirm_only_use_if_familiar {
    my ($self) = @_;
    $self->get_only_use_if_familiar_warning()->press_yes();
}

1;
