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
use testapi;
use parent 'Installation::Partitioner::LibstorageNG::v4::ExpertPartitionerController';
use Installation::Partitioner::LibstorageNG::v4_3::ClonePartitionsDialog;
use Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerPage;
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

    return $self;
}

sub get_clone_partition_dialog {
    my ($self) = @_;
    return $self->{ClonePartitionsDialog};
}


sub add_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_disk($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->_add_partition($args->{partition});
}

sub clone_partition_table {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_disk($args->{disk});
    $self->get_expert_partitioner_page()->open_clone_partition_dialog();
    $self->get_clone_partition_dialog()->select_all_disks();
    $self->get_clone_partition_dialog()->press_ok();
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

1;
