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

use YuiRestClient::Wait;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;

    return $self->init();
}

sub init {
    my $self = shift;

    $self->{btn_add_partition} = $self->{app}->button({id    => '"Y2Partitioner::Widgets::PartitionAddButton"'});
    $self->{btn_add_raid}      = $self->{app}->button({id    => '"Y2Partitioner::Widgets::MdAddButton"'});
    $self->{btn_accept}        = $self->{app}->button({label => 'Accept'});
    $self->{menu_bar}          = $self->{app}->menucollection({id => 'menu_bar'});
    $self->{tbl_devices}       = $self->{app}->table({id => '"Y2Partitioner::Widgets::ConfigurableBlkDevicesTable"'});
    $self->{tree_system_view}  = $self->{app}->tree({id => '"Y2Partitioner::Widgets::OverviewTree"'});

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
    $self->select_item_in_system_view_table('Hard Disks');
    # Cloning option is disabled if any partition is selected, so selecting disk
    $self->{tbl_devices}->select(row => 0);
    $self->{menu_bar}->select('&Device|&Clone Partitions to Another Device...');
    return $self;
}

sub press_add_partition_button {
    my ($self) = @_;
    return $self->{btn_add_partition}->click();
}

sub press_add_raid_button {
    my ($self) = @_;
    return $self->{btn_add_raid}->click();
}

sub press_accept_button {
    my ($self) = @_;
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

1;
