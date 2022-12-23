# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Raid Type Page in
# Add RAID wizard, that are common for all the versions of the page (e.g. for
# both Libstorage and Libstorage-NG).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::RaidTypePage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    RAID_TYPE_PAGE => 'partitioning_raid-menu_add_raid'
};

sub set_raid_level {
    my ($self, $raid_level) = @_;
    assert_screen(RAID_TYPE_PAGE);
    my %entry = (
        0 => 0,
        1 => 1,
        5 => 5,
        6 => 6,
        10 => 'g'
    );
    wait_screen_change { send_key "alt-$entry{$raid_level}"; };
}

sub select_available_devices_table {
    assert_screen(RAID_TYPE_PAGE);
    wait_screen_change { send_key "alt-i"; };    # move to RAID name input field
    wait_screen_change { send_key "tab"; };    # move to "Avilable Devices" table
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

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(RAID_TYPE_PAGE);
}

1;
