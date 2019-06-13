# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Libstorage-NG Expert
# Partitioner.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::ExpertPartitionerController;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::AbstractExpertPartitionerController';
use Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage;
use Installation::Partitioner::LibstorageNG::ExpertPartitionerPage;
use Installation::Partitioner::NewPartitionSizePage;
use Installation::Partitioner::RolePage;
use Installation::Partitioner::LibstorageNG::FormattingOptionsPage;
use Installation::Partitioner::RaidTypePage;
use Installation::Partitioner::RaidOptionsPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        SuggestedPartitioningPage => Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage->new(),
        ExpertPartitionerPage => Installation::Partitioner::LibstorageNG::ExpertPartitionerPage->new({add_partition_shortcut => 'alt-r', add_raid_shortcut => 'alt-d'}),
        NewPartitionSizePage => Installation::Partitioner::NewPartitionSizePage->new({custom_size_shortcut => 'alt-o'}),
        RolePage             => Installation::Partitioner::RolePage->new({raw_volume_shortcut => 'alt-r'}),
        FormattingOptionsPage => Installation::Partitioner::LibstorageNG::FormattingOptionsPage->new({do_not_format_shortcut => 'alt-t', format_shortcut => 'alt-r', filesystem_shortcut => 'alt-f', do_not_mount_shortcut => 'alt-u'}),
        RaidTypePage    => Installation::Partitioner::RaidTypePage->new(),
        RaidOptionsPage => Installation::Partitioner::RaidOptionsPage->new({chunk_size_shortcut => 'alt-u'})
    }, $class;
}

sub get_suggested_partitioning_page {
    my ($self) = @_;
    return $self->{SuggestedPartitioningPage};
}

sub get_raid_options_page {
    my ($self) = @_;
    return $self->{RaidOptionsPage};
}

sub get_expert_partitioner_page {
    my ($self) = @_;
    return $self->{ExpertPartitionerPage};
}

sub get_formatting_options_page {
    my ($self) = @_;
    return $self->{FormattingOptionsPage};
}

sub get_rescan_devices_dialog {
    my ($self) = @_;
    return $self->{RescanDevicesDialog};
}

sub get_new_partition_size_page {
    my ($self) = @_;
    return $self->{NewPartitionSizePage};
}

sub get_raid_type_page {
    my ($self) = @_;
    return $self->{RaidTypePage};
}

sub get_role_page {
    my ($self) = @_;
    return $self->{RolePage};
}

sub run_expert_partitioner {
    my ($self) = @_;
    $self->get_suggested_partitioning_page()->select_start_with_existing_partitions();
}

sub add_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->select_partitions_tab();
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->_add_partition($args->{partition});
}

sub add_raid_partition {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_item_in_system_view_table('raid');
    $self->get_expert_partitioner_page()->select_add_partition_for_raid();
    $self->_add_partition($args);
}

sub add_raid {
    my ($self, $args) = @_;
    my $raid_level            = $args->{raid_level};
    my $device_selection_step = $args->{device_selection_step};
    $self->get_expert_partitioner_page()->select_item_in_system_view_table('raid');
    $self->get_expert_partitioner_page()->press_add_raid_button();
    $self->get_raid_type_page()->set_raid_level($raid_level);
    $self->get_raid_type_page()->select_devices_from_list($device_selection_step);
    $self->get_raid_type_page()->press_next();
    $self->get_raid_options_page()->press_next();
    $self->add_raid_partition($args->{partition});
}

sub _finish_partition_creation {
    my ($self) = @_;
    $self->get_formatting_options_page()->press_next();
}

sub accept_changes {
    my ($self) = @_;
    $self->get_expert_partitioner_page()->press_accept_button();
    $self->get_suggested_partitioning_page()->press_next();
}


1;
