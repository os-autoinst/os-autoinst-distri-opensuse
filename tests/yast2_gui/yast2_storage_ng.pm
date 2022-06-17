# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-storage-ng util-linux
# Summary: This test will check that creating, resizing, encrypting and
#          deleting a partition, a volume group and some logical volumes work as
#          intended.
# - Starts yast2 storage and select /dev/vdb device
# - Create a custom partition on /dev/vdb (200MiB, ext4)
# - Encrypt the partition created (password "susetesting")
# - Validate the partition creating by parsing the output of fdisk -l | grep
# "/dev/vdb1" inside a xterm
# - Starts yast2 storage and select /dev/vdb device
# - Select /dev/vdb1, select custom size and resize it to 170MiB
# - Validate the partition creating by parsing the output of fdisk -l | grep
# "/dev/vdb1" inside a xterm
# - Starts yast2 storage again, select /dev/vdb and delete partition created.
# Checks if device is unpartitioned afterwards.
# - Starts yast2 storage
# - Create a new VG "vgtest" on /dev/vdb
# - Inside "vgtest", create lv1, type: xfs
# - Inside "vgtest", create lv2, type: ext3, encrypt that partition with
# password "susetesting"
# - Inside "vgtest", create lv3, type btrfs, encrypt partition unless is SLE12SP4
# - Inside "vgtest", create lv4, type raw
# - Start xterm, run "lvdisplay /dev/vgtest/lv<number>" for each partition
# - Close xterm, start a new yast2 storage and delete all partitions created
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_tumbleweed is_opensuse);
use utils;

sub add_logical_volume {
    my ($lvname, $role) = shift;
    wait_still_screen 1;
    if (is_sle("15-sp3+")) {
        wait_screen_change { send_key "alt-g" };
    } else {
        wait_screen_change { send_key "alt-a" };
    }
    wait_screen_change { type_string "$lvname" };
    wait_screen_change { send_key "alt-n" };
    # custom size
    send_key("alt-t");
    wait_still_screen 1;
    send_key "alt-s";
    send_key "ctrl-a";
    wait_screen_change { type_string "400MiB" };
    wait_screen_change { send_key "alt-n" };
    send_key "$role";
    wait_screen_change { send_key "alt-n" };
}

sub encrypt_partition {
    wait_still_screen 1;
    send_key("alt-y");
    wait_still_screen 2;
    send_key "alt-n";
    wait_still_screen 2;
    send_key "alt-t";
    wait_screen_change { type_string "susetesting" };
    send_key "alt-v";
    wait_screen_change { type_string "susetesting" };
    send_key("alt-n");
    wait_still_screen 2;
}

sub select_vdb {
    assert_and_click "yast2_storage_ng-select-vdb";
    wait_screen_change { send_key "alt-p" } if is_opensuse || is_sle("15-sp1+");
}

sub select_vdb1 {
    assert_and_click "yast2_storage_ng-select-vdb";
    send_key "tab";
    wait_still_screen 1;
    send_key "tab";
    wait_still_screen 1;
    send_key "down";
}

sub start_y2sn {
    y2_module_guitest::launch_yast2_module_x11("storage", match_timeout => 120);

    wait_screen_change { send_key "alt-y" };
    wait_still_screen 5;
}

sub run {
    select_console "x11";

    ensure_installed 'lvm2' if is_tumbleweed;

    start_y2sn;
    select_vdb;

    ### ADD PARTITION ###
    # /dev/vdb is unpartitioned, now we have to add a new partition
    wait_screen_change { send_key "alt-a" };
    # custom size
    send_key "alt-o";
    wait_still_screen 1;
    # select entry and type partition size
    send_key "alt-s";
    wait_screen_change { type_string "200MiB" };
    # next
    wait_screen_change { send_key "alt-n" };
    # select 'data and isv applications'
    send_key "alt-d";
    # next
    send_key "alt-n";
    wait_still_screen(2);
    assert_and_click "yast2_storage_ng-filesystem-dropdown";
    # XFS is the default filesystem, so we have to move up
    send_key_until_needlematch("yast2_storage_ng-ext4", "up");
    send_key "ret";
    wait_still_screen 2;
    encrypt_partition;
    assert_screen "yast2_storage_ng-partition-created";
    send_key "alt-n";
    wait_still_screen 2;
    send_key "alt-n";
    wait_still_screen 2;
    send_key "alt-f";
    wait_still_screen 2;

    x11_start_program('xterm');
    become_root;
    wait_still_screen 3;
    validate_script_output("fdisk -l | grep /dev/vdb1", sub { m/\/dev\/vdb1\s+\d+\s+\d+\s+\d+.*/ });
    send_key "ctrl-d";
    wait_screen_change { send_key "ctrl-d" };

    ### RESIZE PARTITION ###
    wait_still_screen 3;
    start_y2sn;
    select_vdb unless is_sle("15-sp3+");
    # resize partition
    if (is_opensuse) {
        wait_screen_change { send_key "alt-m" };
        wait_screen_change { send_key "alt-r" };
    } elsif (is_sle("15-sp1+")) {
        if (is_sle("15-sp3+")) {
            select_vdb1;
            hold_key "alt";
            send_key "d";
        }
        else {
            hold_key "alt";
            send_key "m";
        }
        wait_still_screen 1;
        send_key "r";
        release_key "alt";
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
    wait_screen_change { send_key("alt-n") };

    assert_screen "yast2_storage_ng-partition-resized";
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
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
    start_y2sn;
    if (is_sle("15-sp3+")) {
        select_vdb1;
    } else {
        select_vdb;
    }
    wait_screen_change { send_key "alt-l" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-y" };
    assert_screen "yast2_storage_ng-unpartitioned";
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-f" };

    ### CREATE VOLUME GROUP ###
    wait_still_screen 3;
    start_y2sn;
    assert_and_click "yast2_storage_ng-select-vol-management";
    wait_screen_change { send_key "alt-a" };
    # alt-v doesn't work reliably, so we have to use assert_and_click
    assert_and_click "yast2_storage_ng-add-volume-group" if is_sle("<=15");
    send_key 'v' if is_sle("15-sp3+");
    type_string_very_slow "vgtest";
    wait_still_screen 3;
    assert_and_click "yast2_storage_ng-vg-select-device";
    send_key "alt-a";
    wait_screen_change { send_key("alt-n") };

    #  go to system view
    send_key "alt-s" unless is_sle("15-sp3+");
    assert_and_dclick "yast2_storage_ng-select-vgtest";

    my $fs_page_shortcut = "alt-n";

    wait_screen_change { send_key "alt-i" } if is_opensuse || is_sle("15-sp1+");

    # XFS, non encrypted
    add_logical_volume "lv1", "alt-d";
    wait_screen_change { send_key $fs_page_shortcut };

    # EXT4, encrypted
    add_logical_volume "lv2", "alt-d";
    wait_still_screen(2);
    assert_and_click "yast2_storage_ng-filesystem-dropdown";
    send_key_until_needlematch("yast2_storage_ng-ext4", "up");
    send_key "ret";
    encrypt_partition;

    # BtrFS, encrypted
    add_logical_volume "lv3", "alt-d";
    wait_still_screen(2);
    assert_and_click "yast2_storage_ng-filesystem-dropdown";
    send_key_until_needlematch("yast2_storage_ng-btrfs", "up");
    send_key "ret";
    # BtrFS encryption fails on SLE 12.x, therefore we skip it
    encrypt_partition;

    # Raw, non encrypted
    add_logical_volume "lv4", "alt-r";
    wait_still_screen 1;
    wait_screen_change { send_key $fs_page_shortcut };

    # summary and finish
    wait_still_screen 1;
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
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
    start_y2sn;
    assert_and_click "yast2_storage_ng-select-vol-management";
    wait_screen_change { send_key(is_sle() ? "alt-l" : "alt-d") };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-t" };
    wait_still_screen 1;
    wait_screen_change { send_key "alt-n" };
    wait_still_screen 1;
    if (is_sle("15-sp3+")) {
        wait_screen_change { send_key "alt-n" };
    } else {
        wait_screen_change { send_key "alt-f" };
    }
}

1;
