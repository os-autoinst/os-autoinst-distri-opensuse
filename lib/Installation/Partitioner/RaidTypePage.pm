# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: TODO
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::RaidTypePage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    ADD_RAID_STEP1_PAGE => 'partitioning_raid-menu_add_raid'
};

sub set_raid_level {
    my ($self, $raid_level) = @_;
    assert_screen(ADD_RAID_STEP1_PAGE);
    my %entry = (
        0  => 0,
        1  => 1,
        5  => 5,
        6  => 6,
        10 => 'g'
    );
    wait_screen_change { send_key "alt-$entry{$raid_level}"; };
}

sub select_available_devices_table {
    assert_screen(ADD_RAID_STEP1_PAGE);
    wait_screen_change { send_key "alt-i"; };    # move to RAID name input field
    wait_screen_change { send_key "tab"; };      # move to "Avilable Devices" table
}

sub select_devices_from_list {
    my ($self, $step) = @_;
    select_available_devices_table();
    send_key "spc";
    for (1 .. 3) {
        for (1 .. $step) {
            send_key "ctrl-down";
        }
        send_key "spc";
    }
    send_key('alt-a');
}

sub select_rows_in_available_devices_table {
    my ($self, @rows) = @_;
    select_available_devices_table();
    for (my $current_row = 1; $current_row <= $rows[-1]; $current_row++) {
        if ($current_row == $rows[0]) {
            send_key "spc";
            shift @rows;
        }
        send_key "ctrl-down";
    }
    send_key('alt-a');
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(ADD_RAID_STEP1_PAGE);
}

1;
