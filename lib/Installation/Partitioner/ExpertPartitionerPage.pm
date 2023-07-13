# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Expert Partitioner
# Page, that are common for all the versions of the page (e.g. for both
# Libstorage and Libstorage-NG).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::ExpertPartitionerPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    EXPERT_PARTITIONER_PAGE => 'expert-partitioner',
    SELECTED_HARD_DISK => 'partitioning_raid-disk_%s-selected',
    SELECTED_RAID => 'partitioning_raid-raid-selected',
    SELECTED_CURRENT_VOLUME_MANAGEMENT => 'volume-management_system',    # current proposal
    SELECTED_VOLUME_MANAGEMENT => 'volume_management_feature',    # existing partition
    SELECTED_HARD_DISKS => 'partitioning_raid-hard_disks-selected',
    SELECTED_EXISTING_PART => 'partitioning_existing_part_%s-selected',
    CLONE_PARTITION => 'clone_partition',
    ALL_DISKS_SELECTED => 'all_disks_selected',
    PARTITIONS_TAB => 'partitions_tab_selected',
    OVERVIEW_TAB => 'overview_tab_selected',
    NEW_PARTITION_TABLE_TYPE => 'new_partition_table_type',
    SELECTED_CREATE_NEW_TABLE => 'selected_create_new_table',
    DELETING_CURRENT_DEVICES => 'deleting_current_devices',
    NEW_PARTITION_TYPE => 'partition-type'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        add_raid_shortcut => $args->{add_raid_shortcut},
        add_partition_shortcut => $args->{add_partition_shortcut},
        edit_partition_shortcut => $args->{edit_partition_shortcut},
        resize_partition_shortcut => $args->{resize_partition_shortcut},
        partition_table_shortcut => $args->{partition_table_shortcut},
        clone_partition_chortcut => $args->{clone_partition_chortcut},
        ok_clone_shortcut => $args->{ok_clone_shortcut},
        available_target_disks_shortcut => $args->{avail_tgt_disks_shortcut},
        overview_tab => 'alt-o',
        select_msdos_shortcut => $args->{select_msdos_shortcut},
        modify_hard_disks_shortcut => $args->{modify_hard_disks_shortcut},
        press_yes_shortcut => $args->{press_yes_shortcut},
        partitions_tab_shortcut => $args->{partitions_tab_shortcut},
        select_gpt_shortcut => $args->{select_gpt_shortcut},
        select_primary_shortcut => $args->{select_primary_shortcut},
        select_extended_shortcut => $args->{select_extended_shortcut}
    }, $class;
}

sub _select_system_view_section {
    send_key('alt-s');
}

=head2 select_item_in_system_view_table

  select_item_in_system_view_table($item);

Selects one of the features of System View in the Expert Partitioner with any of the 
available options. Each option should find a constant variable representing a needle tag to match.
Default for C<$item> is to match a hard disk with tag partitioning_raid-disk_%s-selected where this
will interpolated by the test_data variable of C<existing_partition>.
=cut

sub select_item_in_system_view_table {
    my ($self, $item) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    _select_system_view_section();
 # TODO: Replace if-else by renaming needle tags using single naming pattern (like for hard disks selection). The conditions were added as a temporary solution.
    if ($item eq 'raid') {
        send_key_until_needlematch(SELECTED_RAID, 'down');
    }
    elsif ($item eq 'volume-management') {
        send_key_until_needlematch(SELECTED_VOLUME_MANAGEMENT, 'down');
    }
    elsif ($item eq 'current-volume-management') {
        send_key_until_needlematch(SELECTED_CURRENT_VOLUME_MANAGEMENT, 'down');
    }
    elsif ($item eq 'hard-disks') {
        send_key_until_needlematch(SELECTED_HARD_DISKS, 'down');
    }
    else {
        send_key_until_needlematch((sprintf SELECTED_HARD_DISK, $item), "down");
    }
}

sub expand_item_in_system_view_table {
    my ($self, $item) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key('right');
}

sub go_top_in_system_view_table {
    _select_system_view_section();
    send_key('home');
}

sub select_partitions_tab {
    my ($self) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key($self->{partitions_tab_shortcut});
}

sub select_overview_tab {
    my ($self) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key($self->{overview_tab});
}

sub press_add_raid_button {
    my ($self) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key($self->{add_raid_shortcut});
}

sub press_add_partition_button {
    my ($self) = @_;
    assert_screen(PARTITIONS_TAB);
    send_key($self->{add_partition_shortcut});
}

sub press_edit_partition_button {
    my ($self) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key($self->{edit_partition_shortcut});
}

sub press_resize_partition_button {
    my ($self) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key($self->{resize_partition_shortcut});
}

sub press_accept_button {
    wait_still_screen;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key('alt-a');
}

sub open_clone_partition_dialog {
    my ($self) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    $self->select_overview_tab;
    assert_screen(OVERVIEW_TAB);
    send_key($self->{partition_table_shortcut});
    for (1 .. 2) { wait_screen_change { send_key "down" } }
    save_screenshot;
    send_key "ret";
}

sub select_all_disks_to_clone {
    my ($self, $numdisks) = @_;
    assert_screen(CLONE_PARTITION);
    send_key($self->{available_target_disks_shortcut});
    send_key "spc";    # Select first disk before going down,
    for (2 .. $numdisks) {    # then start from 2nd.
        send_key "down";
        send_key "spc";
    }
}

sub press_ok_clone {
    my ($self) = @_;
    assert_screen(ALL_DISKS_SELECTED);
    send_key($self->{ok_clone_shortcut});
}

sub modify_hard_disks {
    my ($self, $item) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    _select_system_view_section();
    send_key_until_needlematch(SELECTED_HARD_DISKS, 'down');
    send_key($self->{modify_hard_disks_shortcut});
}
sub open_partition_table_menu {
    my ($self) = @_;
    assert_screen(EXPERT_PARTITIONER_PAGE);
    send_key($self->{partition_table_shortcut});
}

sub create_new_partition_table {
    my ($self) = @_;
    send_key_until_needlematch(SELECTED_CREATE_NEW_TABLE, 'down');
    send_key "ret";
}

sub select_partition_table_type {
    my ($self, $table_type) = @_;
    assert_screen(NEW_PARTITION_TABLE_TYPE);
    my $selection = "select_" . $table_type . "_shortcut";
    send_key($self->{$selection});
    send_key "ret";
}

sub check_confirm_deleting_current_devices {
    my ($self) = @_;
    if (check_screen(DELETING_CURRENT_DEVICES)) {
        send_key($self->{press_yes_shortcut});
    }
}

sub select_new_partition_type {
    my ($self, $partition_type) = @_;
    assert_screen(NEW_PARTITION_TYPE);
    my $selection = "select_" . $partition_type . "_shortcut";
    send_key($self->{$selection});
    send_key "ret";
}

1;
