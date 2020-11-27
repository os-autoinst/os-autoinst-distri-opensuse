# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Expert Partitioner
# Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerPage;
use strict;
use warnings;
use testapi;
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

    $self->{btn_add_partition}      = $self->{app}->button({id    => '"Y2Partitioner::Widgets::PartitionAddButton"'});
    $self->{btn_lvm_add_vg}         = $self->{app}->button({id    => '"Y2Partitioner::Widgets::LvmVgAddButton"'});
    $self->{btn_lvm_add_lv}         = $self->{app}->button({id    => '"Y2Partitioner::Widgets::LvmLvAddButton"'});
    $self->{btn_add_raid}           = $self->{app}->button({id    => '"Y2Partitioner::Widgets::MdAddButton"'});
    $self->{btn_accept}             = $self->{app}->button({label => 'Accept'});
    $self->{menu_bar}               = $self->{app}->menucollection({id => 'menu_bar'});
    $self->{tbl_devices}            = $self->{app}->table({id => '"Y2Partitioner::Widgets::ConfigurableBlkDevicesTable"'});
    $self->{tbl_lvm_devices}        = $self->{app}->table({id => '"Y2Partitioner::Widgets::LvmDevicesTable"'});
    $self->{tree_system_view}       = $self->{app}->tree({id => '"Y2Partitioner::Widgets::OverviewTree"'});
    $self->{btn_add_logical_volume} = $self->{app}->tree({id => '"Y2Partitioner::Widgets::LvmLvAddButton"'});

    return $self;
}

sub open_resize_device {
    my ($self) = @_;
    $self->{menu_bar}->select('&Device|&Resize...');
    return $self;
}

sub select_create_partition_table {
    my ($self) = @_;
    $self->{menu_bar}->select('&Device|Create New &Partition Table...');
    return $self;
}

sub select_item_in_system_view_table {
    my ($self, $item) = @_;

    $self->{tree_system_view}->exist();
    $self->{tree_system_view}->select($item);

    return $self;
}

sub open_clone_partition_dialog {
    my ($self, $disk) = @_;

    $self->{tree_system_view}->exist();
    $self->select_disk($disk) if $disk;
    # Cloning option is disabled if any partition is selected, so selecting disk
    $self->{tbl_devices}->select(row => 0);
    # This is workaround, because row selection doesn't enable clone item in menu bar
    send_key("end");
    send_key("home");
    $self->{menu_bar}->select('&Device|&Clone Partitions to Another Device...');
    return $self;
}

sub press_add_partition_button {
    my ($self) = @_;
    return $self->{btn_add_partition}->click();
}

sub press_add_volume_group_button {
    my ($self) = @_;
    return $self->{btn_lvm_add_vg}->click();
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

sub select_disk {
    my ($self, $disk) = @_;
    $self->select_item_in_system_view_table('Hard Disks|' . $disk);
    $self->{tbl_devices}->select(row => 0);
    return $self;
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

sub select_disk_device_in_table {
    my ($self, $args) = @_;
    my $dev = "/dev/$args->{disk}|$args->{disk}$args->{nr}";
    $self->{tbl_devices}->select(value => $dev);
    send_key('down');
    send_key('up');
}

1;
