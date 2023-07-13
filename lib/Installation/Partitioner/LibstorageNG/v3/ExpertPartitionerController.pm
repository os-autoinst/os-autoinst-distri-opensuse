# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Libstorage-NG (ver.3) Expert
# Partitioner.
#
# Libstorage-NG (ver.3) introduces some different shortcuts comparing to Libstorage.
# Also, it has some UI changes that causes some actions to be performed with the
# different steps (e.g. Partitions Tab should be selected first for "Add" button
# to be visible).
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v3::ExpertPartitionerController;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::Libstorage::ExpertPartitionerController';
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
        ExpertPartitionerPage => Installation::Partitioner::LibstorageNG::ExpertPartitionerPage->new({add_partition_shortcut => 'alt-d', add_raid_shortcut => 'alt-r'}),
        NewPartitionSizePage => Installation::Partitioner::NewPartitionSizePage->new({custom_size_shortcut => 'alt-o'}),
        RolePage => Installation::Partitioner::RolePage->new({raw_volume_shortcut => 'alt-r'}),
        FormattingOptionsPage => Installation::Partitioner::LibstorageNG::FormattingOptionsPage->new({do_not_format_shortcut => 'alt-t', format_shortcut => 'alt-r', filesystem_shortcut => 'alt-f', do_not_mount_shortcut => 'alt-d'}),
        RaidTypePage => Installation::Partitioner::RaidTypePage->new(),
        RaidOptionsPage => Installation::Partitioner::RaidOptionsPage->new({chunk_size_shortcut => 'alt-u'})
    }, $class;
}

=head2 run_expert_partitioner

  run_expert_partitioner([$option]);

Opens the Expert Partiotioner from the Suggested Partitioning page .
if the C<$option> is given it will open one of the current proposal or existing partition.
Expected values are [existing|current].
if none is given the existing partiotion is used as deault.

=cut

sub run_expert_partitioner {
    my ($self, $option) = @_;
    $option //= 'existing';
    record_info $option;
    if ($option eq 'current') {
        $self->get_suggested_partitioning_page()->select_start_with_current_partitions();
    }
    else {
        $self->get_suggested_partitioning_page()->select_start_with_existing_partitions();
    }
}

sub add_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->select_partitions_tab();
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->_add_partition($args->{partition});
}

sub _finish_partition_creation {
    my ($self) = @_;
    $self->get_formatting_options_page()->press_next();
}

1;
