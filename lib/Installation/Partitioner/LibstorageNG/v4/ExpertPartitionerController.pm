# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Libstorage-NG (ver.4)
# Expert Partitioner.
# Libstorage-NG (ver.4) introduces some different shortcuts in comparing to the
# ver.3. Also RAID creation wizard differs.
#
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::v4::ExpertPartitionerController;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::LibstorageNG::v3::ExpertPartitionerController';
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
        ExpertPartitionerPage     => Installation::Partitioner::LibstorageNG::ExpertPartitionerPage->new({
                add_partition_shortcut     => 'alt-r',
                resize_partition_shortcut  => 'alt-r',
                edit_partition_shortcut    => 'alt-e',
                add_raid_shortcut          => 'alt-d',
                partition_table_shortcut   => 'alt-r',
                avail_tgt_disks_shortcut   => 'alt-a',
                ok_clone_shortcut          => 'alt-o',
                select_msdos_shortcut      => 'alt-m',
                select_gpt_shortcut        => 'alt-g',
                modify_hard_disks_shortcut => 'alt-m',
                press_yes_shortcut         => 'alt-y',
                partitions_tab_shortcut    => 'alt-p',
                select_primary_shortcut    => 'alt-p',
                select_extended_shortcut   => 'alt-e'
        }),
        NewPartitionSizePage => Installation::Partitioner::NewPartitionSizePage->new({
                custom_size_shortcut => 'alt-o'
        }),
        EditPartitionSizePage => Installation::Partitioner::NewPartitionSizePage->new({
                custom_size_shortcut => 'alt-u'
        }),
        RolePage => Installation::Partitioner::RolePage->new({
                raw_volume_shortcut => 'alt-r'
        }),
        FormattingOptionsPage => Installation::Partitioner::LibstorageNG::FormattingOptionsPage->new({
                do_not_format_shortcut => 'alt-t',
                format_shortcut        => 'alt-r',
                filesystem_shortcut    => 'alt-f',
                do_not_mount_shortcut  => 'alt-u'
        }),
        EditFormattingOptionsPage => Installation::Partitioner::LibstorageNG::FormattingOptionsPage->new({
                do_not_format_shortcut => 'alt-t',
                format_shortcut        => 'alt-a',
                filesystem_shortcut    => 'alt-f',
                do_not_mount_shortcut  => 'alt-o'
        }),
        RaidTypePage    => Installation::Partitioner::RaidTypePage->new(),
        RaidOptionsPage => Installation::Partitioner::RaidOptionsPage->new({
                chunk_size_shortcut => 'alt-u'
        })
    }, $class;
}

sub get_edit_formatting_options_page {
    my ($self) = @_;
    return $self->{EditFormattingOptionsPage}; # There are different shortcuts when we edit an existing partition than if we add one but otherwise the page is identical
}

sub get_edit_partition_size_page {
    my ($self) = @_;
    return $self->{EditPartitionSizePage};     # Same as get_formatting_options_edit_page
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

=head2 resize_partition_on_gpt_disk(args)

  resize_partition_on_gpt_disk(args)

Once you have an instance of the page and you are in the Expert Partitioning
C<resize_partition_on_gpt_disk> can be invoked to resize any partition or hard disk.
The test_data hash should contains the variables C<disk>, C<existing_partition> and C<part_size>.
C<disk> is used to select one of the options in the menu, like LVM or Bcache and a needle should match with the C<disk> value included. C<existing_partition> represents the partition or hard disk that you want to resize with the value of C<part_size>.
=cut

sub resize_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->go_top_in_system_view_table();
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->expand_item_in_system_view_table();
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{existing_partition});
    $self->get_expert_partitioner_page()->press_resize_partition_button();
    $self->get_edit_partition_size_page()->select_custom_size_radiobutton();
    $self->get_edit_partition_size_page()->enter_size($args->{part_size});
    $self->get_edit_partition_size_page()->press_next();
}

sub edit_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->go_top_in_system_view_table();
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->expand_item_in_system_view_table();
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{existing_partition});
    $self->get_expert_partitioner_page()->press_edit_partition_button();
    $self->get_edit_formatting_options_page()->select_format_device_radiobutton($args->{skip});
    $self->get_edit_formatting_options_page()->select_filesystem($args->{fs_type}, $args->{skip});
    $self->get_edit_formatting_options_page()->select_mount_device_radiobutton();
    $self->get_edit_formatting_options_page()->fill_in_mount_point_field($args->{mount_point});
    $self->get_edit_formatting_options_page()->press_next();
}

sub clone_partition_table {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->go_top_in_system_view_table();
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->open_clone_partition_dialog();
    $self->get_expert_partitioner_page()->select_all_disks_to_clone($args->{numdisks});
    $self->get_expert_partitioner_page()->press_ok_clone();
}

sub create_new_partition_table {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->open_partition_table_menu();
    $self->get_expert_partitioner_page()->create_new_partition_table();
    $self->get_expert_partitioner_page()->check_confirm_deleting_current_devices();
    $self->get_expert_partitioner_page()->select_partition_table_type($args->{table_type});
}

sub add_partition_msdos {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->select_partitions_tab();
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_expert_partitioner_page()->select_new_partition_type($args->{partition_type});
    $self->add_new_partition($args->{partition});
}

sub add_new_partition {
    my ($self, $args) = @_;
    if ($args->{size} eq "max") {
        $self->get_edit_partition_size_page()->press_next();
    }
    else {
        $self->set_new_partition_size($args->{size});
    }
    $self->_set_partition_role($args->{role});
    $self->_set_partition_options($args);
    $self->_finish_partition_creation();
}

sub set_new_partition_size {
    my ($self, $size) = @_;
    if (defined $size) {
        $self->get_edit_partition_size_page()->select_custom_size_radiobutton();
        $self->get_edit_partition_size_page()->enter_size($size);
    }
    $self->get_edit_partition_size_page()->press_next();
}

1;
