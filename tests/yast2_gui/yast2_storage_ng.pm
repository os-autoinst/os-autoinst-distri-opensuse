# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This test will check that creating, resizing, encrypting and
#          deleting a partition, a volume group and some logical volumes work as
#          intended.
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "y2x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_tumbleweed is_opensuse);

sub add_logical_volume {
    my ($lvname, $role) = shift;
    wait_still_screen 1;
    wait_screen_change { send_key "alt-a" };
    wait_screen_change { type_string "$lvname" };
    wait_screen_change { send_key "alt-n" };
    # custom size
    send_key(is_sle('<=12-sp4') ? "alt-c" : "alt-t");
    wait_still_screen 1;
    send_key "alt-s";
    wait_screen_change { type_string "400MiB" };
    wait_screen_change { send_key "alt-n" };
    send_key "$role";
    wait_screen_change { send_key "alt-n" };
}

sub encrypt_partition {
    wait_still_screen 1;
    send_key(is_sle('<=12-sp4') ? "alt-c" : "alt-y");
    wait_screen_change { send_key "alt-n" };
    send_key "alt-t";
    wait_screen_change { type_string "susetesting" };
    send_key "alt-v";
    wait_screen_change { type_string "susetesting" };
    wait_screen_change { send_key(is_sle('<=12-sp4') ? "alt-f" : "alt-n") };
}

sub select_vdb {
    if (is_sle('<=12-sp4')) {
        assert_and_dclick "yast2_storage_ng-select-vdb";
    } else {
        assert_and_click "yast2_storage_ng-select-vdb";
        wait_screen_change { send_key "alt-p" } if is_opensuse;
    }
}

sub start_y2sn {
    my $self = shift;
    $self->launch_yast2_module_x11("storage", match_timeout => 120);

    wait_screen_change { send_key "alt-y" };
    wait_still_screen 5;
}

sub run {
    my $self = shift;
    select_console "x11";

    ensure_installed 'lvm2' if is_tumbleweed;

    start_y2sn $self;
    select_vdb;

    ### ADD PARTITION ###
    # /dev/vdb is unpartitioned, now we have to add a new partition
    wait_screen_change { send_key "alt-a" };
    if (is_sle('<=12-sp4')) {
        wait_screen_change { send_key "alt-n" };
        # custom size
        send_key "alt-c";
    } else {
        # custom size
        send_key "alt-o";
    }
    wait_still_screen 1;
    # select entry and type partition size
    send_key "alt-s";
    wait_screen_change { type_string "200MiB" };
    # next
    wait_screen_change { send_key "alt-n" };
    # select 'data and isv applications'
    send_key "alt-d";
    # next
    wait_screen_change { send_key "alt-n" };
    assert_and_click "yast2_storage_ng-filesystem-dropdown";
    # XFS is the default filesystem, so we have to move up
    send_key_until_needlematch("yast2_storage_ng-ext4", "up");
    send_key "ret";
    # encrypt the partition
    wait_still_screen 1;
    # on SLE 12.x it's not possible to resize an ext4 encrypted filesystem,
    if (is_sle("<=12-sp4")) {
        wait_screen_change { send_key "alt-f" };
    } else {
        encrypt_partition;
    }
    assert_screen "yast2_storage_ng-partition-created";
    wait_screen_change { send_key "alt-n" };
    wait_screen_change { send_key "alt-f" };

    x11_start_program('xterm');
    become_root;
    wait_still_screen 3;
    validate_script_output("fdisk -l | grep /dev/vdb1", sub { m/\/dev\/vdb1\s+\d+\s+\d+\s+\d+.*/ });
    send_key "ctrl-d";
    wait_screen_change { send_key "ctrl-d" };

    ### RESIZE PARTITION ###
    wait_still_screen 3;
    start_y2sn $self;
    select_vdb;
    # resize partition
    if (is_opensuse) {
        wait_screen_change { send_key "alt-m" };
        wait_screen_change { send_key "alt-r" };
    } else {
        wait_screen_change { send_key "alt-i" };
    }
    wait_still_screen 1;
    # custom size
    send_key "alt-u";
    wait_still_screen 1;
    # select entry and type partition size
    send_key "alt-s";
    wait_screen_change { type_string "170MiB" };
    wait_screen_change { send_key(is_sle('<=12-sp4') ? "alt-o" : "alt-n") };

    assert_screen "yast2_storage_ng-partition-resized";
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-f" };

    # check that the partion is ~170MiB (output is: /dev/vdb1     2048 355477  353430 172.6M 83 Linux)
    x11_start_program('xterm');
    become_root;
    wait_still_screen 3;
    validate_script_output("fdisk -l | grep /dev/vdb1", sub { m/\/dev\/vdb1\s+\d+\s+\d+\s+\d+\s+17.*/ });
    send_key "ctrl-d";
    wait_screen_change { send_key "ctrl-d" };

    ### DELETE PARTITION ###
    wait_still_screen 3;
    start_y2sn $self;
    select_vdb;
    wait_screen_change { send_key "alt-l" };
    wait_screen_change { send_key "alt-y" };
    assert_screen "yast2_storage_ng-unpartitioned";
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-f" };

    ### CREATE VOLUME GROUP ###
    wait_still_screen 3;
    start_y2sn $self;
    assert_and_click "yast2_storage_ng-select-vol-management";
    wait_screen_change { send_key "alt-a" };
    # alt-v doesn't work reliably, so we have to use assert_and_click
    assert_and_click "yast2_storage_ng-add-volume-group" if is_sle;
    wait_screen_change { type_string "vgtest" };
    assert_and_click "yast2_storage_ng-vg-select-device";
    send_key "alt-a";
    wait_screen_change { send_key(is_sle('<=12-sp4') ? "alt-f" : "alt-n") };

    #  go to system view
    send_key "alt-s";
    assert_and_dclick "yast2_storage_ng-select-vgtest";

    my $fs_page_shortcut = is_sle("<=12-sp4") ? "alt-f" : "alt-n";
    wait_screen_change { send_key "alt-i" } if is_opensuse;

    # XFS, non encrypted
    add_logical_volume "lv1", "alt-d";
    wait_screen_change { send_key $fs_page_shortcut };

    # EXT4, encrypted
    add_logical_volume "lv2", "alt-d";
    assert_and_click "yast2_storage_ng-filesystem-dropdown";
    send_key_until_needlematch("yast2_storage_ng-ext4", "up");
    send_key "ret";
    encrypt_partition;

    # BtrFS, encrypted
    add_logical_volume "lv3", "alt-d";
    assert_and_click "yast2_storage_ng-filesystem-dropdown";
    send_key_until_needlematch("yast2_storage_ng-btrfs", "up");
    send_key "ret";
    # BtrFS encryption fails on SLE 12.x, therefore we skip it
    if (is_sle("<=12-sp4")) {
        wait_screen_change { send_key $fs_page_shortcut };
    } else {
        encrypt_partition;
    }

    # Raw, non encrypted
    my $raw_shortcut = is_sle("<=12-sp4") ? "alt-a" : "alt-r";
    add_logical_volume "lv4", $raw_shortcut;
    # on SLE 12.x the alt-a shortcut doesn't seem to work reliably, so here we 'force' the raw format
    send_key "alt-d" if is_sle("<=12-sp4");
    wait_still_screen 1;
    wait_screen_change { send_key $fs_page_shortcut };

    # summary and finish
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-f" };

    # check that all logical volumes have been created
    wait_still_screen 5;
    x11_start_program('xterm');
    become_root;
    wait_still_screen 3;
    for (my $i = 1; $i <= 4; $i++) {
        assert_script_run "lvdisplay /dev/vgtest/lv$i";
    }
    send_key "ctrl-d";
    wait_screen_change { send_key "ctrl-d" };

    # Remove the volume group and all its logical volumes
    wait_still_screen 1;
    start_y2sn $self;
    assert_and_click "yast2_storage_ng-select-vol-management";
    wait_screen_change { send_key(is_sle() ? "alt-l" : "alt-d") };
    wait_screen_change { send_key "alt-t" };
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-f" };
}

1;
