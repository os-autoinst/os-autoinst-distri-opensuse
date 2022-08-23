# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test to take the smallest disk in storage_ng scenarios
#    Otherwise the partitioning proposal will use a free disk, which makes
#    rebooting a game of chance on real hardware
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use Utils::Backends;
use version_utils qw(is_storage_ng);
use partition_setup qw(take_first_disk);

sub run {
    if (!is_storage_ng) {
        record_info "Requires storage_ng", "This module only works with storage_ng which is not present. Selecting first disk instead";
        return take_first_disk;
    }

    if (get_var('BACKEND', '') =~ /ikvm|ipmi|spvm|pvm_hmc/) {
        select_console 'root-ssh';
    }
    else {
        select_console 'root-console';
    }
    my $lsblkcmd = q/echo "[$(lsblk -n -l -o SIZE,NAME -d -e 7,11,254 -b | sort -n | awk '(NR == 1) {print $2}')]"/;
    $lsblkcmd = q/echo "[$(lsblk -n -l -o SIZE,NAME,TYPE -e 7,11 -b | grep 'mpath' | sort -n | awk '(NR == 1) {print $2}')]"/
      if (get_var('MULTIPATH') and (get_var('MULTIPATH_CONFIRM') !~ /\bNO\b/i));
    my $output = script_output $lsblkcmd;
    $output =~ /\[([\w\.]+)\]/;
    my $device = $1;
    # Provide an interface to set small disk name
    if (get_var('SMALL_DISK')) {
        $device = get_var('SMALL_DISK');
    }
    record_info "$device selected", "Will use disk [$device] for installation";

    select_console 'installation';
    # Detect SLE-12 and use ALT-C shortcut
    if (get_var('VERSION') =~ /^12/ && check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';
    }
    else {
        send_key $cmd{guidedsetup};    # select guided setup
    }
    assert_screen 'select-hard-disks';
    # Ensure all devices are deselected. We deselect at least one
    my $extra_disks_to_deselect = 0;
    check_screen [qw(select-hard-disks-two-selected select-hard-disks-three-selected)];
    $extra_disks_to_deselect += 1 if match_has_tag 'select-hard-disks-two-selected';
    $extra_disks_to_deselect += 2 if match_has_tag 'select-hard-disks-three-selected';
    # First focus on disks list
    send_key 'tab';
    if (check_var('VIDEOMODE', 'text')) {
        wait_still_screen 3;
        send_key 'tab';
    }
    # Deselect the disks. Scrolling through the list of devices is different in textmode
    my $scrolldown = check_var('VIDEOMODE', 'text') ? 'tab' : 'down';
    my $scrollup = check_var('VIDEOMODE', 'text') ? 'shift-tab' : 'up';
    for (0 .. $extra_disks_to_deselect) { send_key 'spc'; send_key $scrolldown; }
    wait_still_screen 3;

    # Select $device
    if (check_var('VIDEOMODE', 'text')) {
        for (0 .. $extra_disks_to_deselect) { send_key $scrollup; }    # Return to top of devices' list
        send_key_until_needlematch "hard-disk-dev-$device-not-selected", $scrolldown;
        send_key 'spc';
        # At this time, only one device should be selected. Send shift-tabs until focus is out of the devices' list
        send_key_until_needlematch 'select-hard-disks-one-selected', 'shift-tab';
    }
    else {
        assert_and_click "hard-disk-dev-$device-not-selected";
    }
    # Check only one disk was selected
    assert_screen 'select-hard-disks-one-selected';
    send_key $cmd{next};

    assert_screen [qw(existing-partitions partition-scheme)];
    if (match_has_tag 'existing-partitions') {
        if (is_ipmi && !check_var('VIDEOMODE', 'text')) {
            send_key_until_needlematch("remove-menu", "tab");
            while (check_screen('remove-menu', 3)) {
                send_key 'spc';
                send_key 'down';
                send_key 'ret';
                send_key 'tab';
            }
            save_screenshot;
        }
        else {
            send_key $cmd{next};
            assert_screen 'partition-scheme';
        }
    }
    send_key_until_needlematch 'after-partitioning', $cmd{next}, 11, 3;
}

1;
