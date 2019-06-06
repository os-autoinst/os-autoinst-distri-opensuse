# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Libstorage Expert
# Partitioner.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::Libstorage::ExpertPartitionerController;
use strict;
use warnings;
use testapi;
use Installation::Partitioner::Libstorage::SuggestedPartitioningPage;
use Installation::Partitioner::Libstorage::PreparingHardDiskPage;
use Installation::Partitioner::ExpertPartitionerPage;
use Installation::Partitioner::NewPartitionTypePage;
use Installation::Partitioner::NewPartitionSizePage;
use Installation::Partitioner::RolePage;
use Installation::Partitioner::Libstorage::FormattingOptionsPage;
use Installation::Partitioner::RaidTypePage;
use Installation::Partitioner::RaidOptionsPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        SuggestedPartitioningPage => Installation::Partitioner::Libstorage::SuggestedPartitioningPage->new(),
        PreparingHardDiskPage     => Installation::Partitioner::Libstorage::PreparingHardDiskPage->new(),
        ExpertPartitionerPage     => Installation::Partitioner::ExpertPartitionerPage->new({add_partition_shortcut => 'alt-d', add_raid_shortcut => 'alt-i'}),
        NewPartitionSizePage      => Installation::Partitioner::NewPartitionSizePage->new({custom_size_shortcut => 'alt-c'}),
        NewPartitionTypePage      => Installation::Partitioner::NewPartitionTypePage->new(),
        RolePage                  => Installation::Partitioner::RolePage->new({raw_volume_shortcut => 'alt-a'}),
        FormattingOptionsPage => Installation::Partitioner::Libstorage::FormattingOptionsPage->new({do_not_format_shortcut => 'alt-d', format_shortcut => 'alt-a', filesystem_shortcut => 'alt-s', do_not_mount_shortcut => 'alt-u'}),
        RaidTypePage    => Installation::Partitioner::RaidTypePage->new(),
        RaidOptionsPage => Installation::Partitioner::RaidOptionsPage->new({chunk_size_shortcut => 'alt-c'})
    }, $class;
}

sub get_suggested_partitioning_page {
    my ($self) = @_;
    return $self->{SuggestedPartitioningPage};
}

sub get_expert_partitioner_page {
    my ($self) = @_;
    return $self->{ExpertPartitionerPage};
}

sub get_preparing_hard_disk_page {
    my ($self) = @_;
    return $self->{PreparingHardDiskPage};
}

sub get_new_partition_size_page {
    my ($self) = @_;
    return $self->{NewPartitionSizePage};
}

sub get_new_partition_type_page {
    my ($self) = @_;
    return $self->{NewPartitionTypePage};
}

sub get_role_page {
    my ($self) = @_;
    return $self->{RolePage};
}

sub get_formatting_options_page {
    my ($self) = @_;
    return $self->{FormattingOptionsPage};
}

sub get_raid_type_page {
    my ($self) = @_;
    return $self->{RaidTypePage};
}

sub get_raid_options_page {
    my ($self) = @_;
    return $self->{RaidOptionsPage};
}

sub run_expert_partitioner {
    my ($self) = @_;
    $self->get_suggested_partitioning_page()->press_create_partition_setup_button();
    $self->get_preparing_hard_disk_page()->select_custom_partitioning_radiobutton();
    $self->get_preparing_hard_disk_page()->press_next();
    $self->get_expert_partitioner_page()->select_item_in_system_view_table('hard-disks');
    $self->get_expert_partitioner_page()->expand_item_in_system_view_table();
}

sub add_partition_on_gpt_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->_add_partition($args->{partition});
}

sub add_partition_on_msdos_disk {
    my ($self, $args) = @_;
    $self->get_expert_partitioner_page()->select_item_in_system_view_table($args->{disk});
    $self->get_expert_partitioner_page()->press_add_partition_button();
    $self->get_new_partition_type_page()->press_next();
    $self->_add_partition($args->{partition});
}

# The method proceeds through the Expert Partitioner Wizard and sets the data,
# that is specified by the method parameters.
# This allows a test to select the specified options, depending on the data
# provided to the method, instead of making different set of methods for all
# the required test combinations.
sub _add_partition {
    my ($self, $args) = @_;
    my $size               = $args->{size};
    my $role               = $args->{role};
    my $id                 = $args->{id};
    my $formatting_options = $args->{formatting_options};
    my $mounting_options   = $args->{mounting_options};

    # Check if $size is defined to allow entering '0' size.
    if (defined $size) {
        $self->get_new_partition_size_page()->select_custom_size_radiobutton();
        $self->get_new_partition_size_page()->enter_size($size);
        $self->get_new_partition_size_page()->press_next();
    }
    if ($role) {
        $self->get_role_page()->select_role_radiobutton($role);
    }
    $self->get_role_page()->press_next();
    # Set Formatting Options:
    if ($formatting_options) {
        if ($formatting_options->{should_format}) {
            $self->get_formatting_options_page()->select_format_partition_radiobutton();
            if ($formatting_options->{filesystem}) {
                $self->get_formatting_options_page()->select_filesystem($formatting_options->{filesystem});
            }
        }
        else {
            $self->get_formatting_options_page()->select_do_not_format_partition_radiobutton();
        }
    }
    if ($id) {
        $self->get_formatting_options_page()->select_file_system_id($id);
    }
    # Set Mounting Options:
    if ($mounting_options) {
        if ($mounting_options->{should_mount}) {
            $self->get_formatting_options_page()->select_mount_partition_radiobutton();
            if ($mounting_options->{mount_point}) {
                $self->get_formatting_options_page()->fill_in_mount_point_field($mounting_options->{mount_point});
            }
        }
        else {
            $self->get_formatting_options_page()->select_do_not_mount_partition_radiobutton();
        }
    }
    $self->get_formatting_options_page()->press_finish();
}

sub add_raid {
    my ($self, $args) = @_;
    my $raid_level            = $args->{raid_level};
    my $chunk_size            = $args->{chunk_size};
    my $device_selection_step = $args->{device_selection_step};
    $self->get_expert_partitioner_page()->select_item_in_system_view_table('raid');
    $self->get_expert_partitioner_page()->press_add_raid_button();
    $self->get_raid_type_page()->set_raid_level($raid_level);
    $self->get_raid_type_page()->select_devices_from_list($device_selection_step);
    $self->get_raid_type_page()->press_next();
    $self->get_raid_options_page()->select_chunk_size($chunk_size);
    $self->get_raid_options_page()->press_next();
    $self->_add_partition($args->{partition});
}

sub add_raid_partition {
    my ($self, $args) = @_;
    $self->_add_partition($args);
}

sub accept_changes {
    my ($self) = @_;
    $self->get_expert_partitioner_page()->press_accept_button();
}


1;
