# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Expert Partitioner
# Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::Navigation::NavigationBase';
use parent 'Installation::Partitioner::LibstorageNG::ExpertPartitionerPage';

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;

    return $self->init();
}

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{btn_add_partition} = $self->{app}->button({id => '"Y2Partitioner::Widgets::PartitionAddButton"'});
    $self->{btn_edit_partition} = $self->{app}->button({id => '"Y2Partitioner::Widgets::BlkDeviceEditButton"'});
    $self->{btn_delete_partition} = $self->{app}->button({id => '"Y2Partitioner::Widgets::PartitionDeleteButton"'});
    $self->{btn_lvm_add_vg} = $self->{app}->button({id => '"Y2Partitioner::Widgets::LvmVgAddButton"'});
    $self->{btn_lvm_delete_vg} = $self->{app}->button({id => '"Y2Partitioner::Widgets::LvmVgDeleteButton"'});
    $self->{btn_lvm_add_lv} = $self->{app}->button({id => '"Y2Partitioner::Widgets::LvmLvAddButton"'});
    $self->{btn_add_raid} = $self->{app}->button({id => '"Y2Partitioner::Widgets::MdAddButton"'});
    $self->{btn_accept} = $self->{app}->button({label => 'Accept'});
    $self->{btn_cancel} = $self->{app}->button({id => 'abort'});
    $self->{mnc_bar} = $self->{app}->menucollection({id => 'menu_bar'});
    $self->{tbl_devices} = $self->{app}->table({id => '"Y2Partitioner::Widgets::ConfigurableBlkDevicesTable"'});
    $self->{tbl_lvm_devices} = $self->{app}->table({id => '"Y2Partitioner::Widgets::LvmDevicesTable"'});
    $self->{tre_system_view} = $self->{app}->tree({id => '"Y2Partitioner::Widgets::OverviewTree"'});
    $self->{btn_add_logical_volume} = $self->{app}->tree({id => '"Y2Partitioner::Widgets::LvmLvAddButton"'});

    return $self;
}

sub is_shown {
    my ($self) = @_;
    # Check for menu bar to be existing on Expert Partitioner Page.
    # The menu bar is chosen as the element that allows to identify that Expert Partitioner Page is opened,
    # as the page does not have any unique header.
    $self->{mnc_bar}->exist();
}

sub open_resize_device {
    my ($self) = @_;
    $self->{mnc_bar}->select('&Device|&Resize...');
    return $self;
}

sub select_create_partition_table {
    my ($self) = @_;
    $self->{mnc_bar}->select('&Device|Create New &Partition Table...');
    return $self;
}

sub select_item_in_system_view_table {
    my ($self, $item) = @_;

    $self->{tre_system_view}->exist();
    $self->{tre_system_view}->select($item);

    return $self;
}

sub open_clone_partition_dialog {
    my ($self, $disk) = @_;

    $self->{tre_system_view}->exist();
    $self->select_disk($disk) if $disk;
    # Cloning option is disabled if any partition is selected, so selecting disk
    $self->{tbl_devices}->select(row => 0);
    # This is workaround, because row selection doesn't enable clone item in menu bar
    send_key("end");
    send_key("home");
    $self->{mnc_bar}->select('&Device|&Clone Partitions to Another Device...');
    return $self;
}

sub press_add_partition_button {
    my ($self) = @_;
    return $self->{btn_add_partition}->click();
}

sub press_edit_partition_button {
    my ($self) = @_;
    return $self->{btn_edit_partition}->click();
}

sub press_delete_partition_button {
    my ($self) = @_;
    return $self->{btn_delete_partition}->click();
}

sub press_add_volume_group_button {
    my ($self) = @_;
    return $self->{btn_lvm_add_vg}->click();
}

sub press_delete_volume_group_button {
    my ($self) = @_;
    return $self->{btn_lvm_delete_vg}->click();
}

sub press_add_logical_volume_button {
    my ($self) = @_;
    return $self->{btn_lvm_add_lv}->click();
}

sub press_add_raid_button {
    my ($self) = @_;
    return $self->{btn_add_raid}->click();
}

sub press_accept_button {
    my ($self) = @_;
    $self->{btn_accept}->exist();
    return $self->{btn_accept}->click();
}

sub press_cancel_button {
    my ($self) = @_;
    $self->{btn_cancel}->click();
}

sub select_disk {
    my ($self, $disk) = @_;
    $self->select_item_in_system_view_table('Hard Disks|' . $disk);
    $self->{tbl_devices}->select(row => 0);
    return $self;
}

sub select_disk_partition {
    my ($self, $args) = @_;
    $self->select_disk($args->{disk});
    $self->{tbl_devices}->select(value => '/dev/' . $args->{disk} . '|' . $args->{partition});
    send_key('up');
    send_key('down');
}

sub select_raid {
    my ($self, $disk) = @_;
    return $self->select_item_in_system_view_table('RAID');
}

sub select_lvm {
    my ($self, $disk) = @_;
    return $self->select_item_in_system_view_table('LVM Volume Groups');
}

sub select_volume_group {
    my ($self, $vg) = @_;
    return $self->select_item_in_system_view_table('LVM Volume Groups|' . $vg);
}

sub select_logical_volume {
    my ($self, $args) = @_;
    $self->select_volume_group($args->{volume_group});
    $self->{tbl_lvm_devices}->select(value => '/dev/' . $args->{volume_group} . '|' . $args->{logical_volume});
    send_key('up');
    send_key('down');
}

1;
