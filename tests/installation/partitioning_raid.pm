# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: split the partitioning monster into smaller pieces
# Maintainer: Stephan Kulow <coolo@suse.de>, Sergio Lindo Mansilla <slindomansilla@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils 'is_storage_ng';
use partition_setup 'wipe_existing_partitions';

# add a new primary partition
#   $type == 3 => 0xFD Linux RAID
sub addpart {
    my ($part) = @_;
    my $size = 0;

    if    ($part eq 'boot') { $size = 300; }
    elsif ($part eq 'root') { $size = 8000; }
    elsif ($part eq 'swap') { $size = 100; }
    else                    { die 'Unknown argument'; }

    assert_screen "expert-partitioner";
    send_key $cmd{addpart};
    if (is_storage_ng) {
        # No partitioning type page ATM
        record_soft_failure 'bsc#1055743';
    }
    elsif (!get_var('UEFI')) {    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
        assert_screen "partitioning-type";
        send_key $cmd{next};
    }

    assert_screen "partition-size";
    if (is_storage_ng) {
        # maximum size is selected by default
        send_key 'alt-c';
        assert_screen 'partition-custom-size-selected';
        send_key 'alt-s';
    }
    for (1 .. 10) {
        send_key "backspace";
    }
    type_string $size . "mb";
    assert_screen "partition-size";
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key "alt-a";    # Raw Volume
    send_key $cmd{next};
    assert_screen 'partition-format';
    send_key $cmd{donotformat};
    send_key "tab";
    send_key 'alt-i' if is_storage_ng;    # Select file system
    if ($part eq 'boot' and get_var('UEFI')) {
        send_key_until_needlematch 'partition-selected-efi-type', 'down';
    }
    else {
        send_key_until_needlematch 'partition-selected-raid-type', 'down';
    }
    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
}

sub addraid {
    my ($step, $chunksize) = @_;
    send_key "spc";
    for (1 .. 3) {
        for (1 .. $step) {
            send_key "ctrl-down";
        }
        send_key "spc";
    }

    # add
    send_key $cmd{add};
    wait_still_screen;
    save_screenshot;
    wait_screen_change {
        send_key $cmd{next};
    };

    # chunk size selection
    if ($chunksize) {
        type_string "\t$chunksize";
    }
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key "alt-o";    # Operating System

    wait_screen_change { send_key $cmd{next} };
}

sub setraidlevel {
    my ($level) = @_;
    my %entry = (0 => 0, 1 => 1, 5 => 5, 6 => 6, 10 => 'g');
    wait_screen_change { send_key "alt-$entry{$level}"; };

    wait_screen_change { send_key "alt-i"; };    # move to RAID name input field
    wait_screen_change { send_key "tab"; };      # skip RAID name input field
}

sub set_lvm {
    send_key "shift-tab";
    # select LVM
    send_key "down";

    # create volume group
    send_key "alt-d";
    send_key "down";
    send_key "ret";

    assert_screen 'lvmsetupraid';
    # add all unformated lvm devices
    send_key "alt-d";

    # set volume name
    send_key "alt-v";
    type_string "root";
    assert_screen 'volumegroup-name-root';

    send_key $cmd{finish};
    wait_still_screen;

    # create logical volume
    send_key "alt-d";
    send_key "down";
    send_key "down";
    send_key "ret";

    # create normal volume with name root
    type_string "root";
    assert_screen 'volume-name-root';
    send_key $cmd{next};

    # keep default
    send_key $cmd{next};

    send_key "alt-o";    # Operating System
    send_key $cmd{next};

    # keep default to mount as root and btrfs
    wait_screen_change { send_key $cmd{finish} };
}

sub run {
    # create partitioning
    send_key(is_storage_ng() ? $cmd{expertpartitioner} : $cmd{createpartsetup});

    # With storage ng, we go directly to expert partitioner and invalidate configuration by rescan
    if (is_storage_ng) {
        send_key $cmd{rescandevices};              # Rescan devices
        assert_screen 'rescan-devices-warning';    # Confirm rescan
        send_key 'alt-y';
        wait_still_screen;                         # Wait until rescan is done
    }
    else {
        assert_screen 'createpartsetup';
        # user defined
        send_key $cmd{custompart};
        assert_screen 'custompart_option-selected';
        send_key $cmd{next};
    }
    assert_screen 'custompart';
    send_key "tab";

    assert_screen 'custompart_systemview-selected';
    send_key "down";
    assert_screen 'partitioning_raid-hard_disks-selected';

    if (get_var("OFW")) {    ## no RAID /boot partition for ppc
        if (is_storage_ng) {
            record_soft_failure 'bsc#1063844';    # Cannot add partition from menu option "hard disks"
            send_key 'down';
            assert_screen 'partitioning_raid-disk_vda-selected';
            send_key 'alt-d';
        }
        else {
            send_key 'alt-p';
        }
        if (!get_var('UEFI')) {                   # partitioning type does not appear when GPT disk used, GPT is default for UEFI
            if (is_storage_ng) {
                record_soft_failure 'bsc#1055743';    # No partitioning type page ATM
            }
            else {
                assert_screen 'partitioning-type';
                send_key 'alt-n';
            }
        }
        assert_screen 'partitioning-size';
        send_key 'alt-c' if is_storage_ng;
        my $size_hotkey = (is_storage_ng) ? 'alt-s' : 'ctrl-a';
        wait_screen_change { send_key $size_hotkey };
        type_string "200 MB";
        assert_screen 'partitioning_raid-custom-size-200MB';
        send_key 'alt-n';
        assert_screen 'partition-role';
        send_key "alt-a";
        assert_screen 'partitioning_raid-partition_role_raw_volume';
        send_key 'alt-n';
        assert_screen 'partition-format';
        my $not_format_hotkey = (is_storage_ng) ? 'alt-t' : 'ctrl-d';
        send_key $not_format_hotkey;
        assert_screen 'partitioning_raid-format_noformat';
        send_key 'alt-i';
        assert_screen 'partitioning_raid-file_system_id-selected';
        my $direction_key = (is_storage_ng) ? 'up' : 'down';
        send_key_until_needlematch 'filesystem-prep', $direction_key;
        my $next_hotkey = (is_storage_ng) ? 'alt-n' : 'alt-f';
        send_key $next_hotkey;
        assert_screen 'custompart';
        send_key 'alt-s';
        send_key 'right';
        assert_screen 'partitioning_raid-hard_disks-unfolded';
        send_key 'down';
    }
    else {
        send_key "right" unless is_storage_ng;
        assert_screen 'partitioning_raid-hard_disks-unfolded';
        send_key "down";
    }

    for (qw(vda vdb vdc vdd)) {
        send_key_until_needlematch "partitioning_raid-disk_$_-selected", "down";
        addpart('boot');
        # Need to navigate to the disk manually
        send_key_until_needlematch "partitioning_raid-disk_$_-selected", 'down' if is_storage_ng;
        assert_screen 'partitioning_raid-part_boot_added';
        addpart('root');
        # Need to navigate to the disk manually
        send_key_until_needlematch "partitioning_raid-disk_$_-selected", 'down' if is_storage_ng;
        assert_screen 'partitioning_raid-part_root_added';
        addpart('swap');
        # Need to navigate to the disk manually
        send_key_until_needlematch "partitioning_raid-disk_$_-selected", 'down' if is_storage_ng;
        assert_screen 'raid-partition';

        # select next disk
        send_key "shift-tab" unless is_storage_ng;
        send_key "shift-tab" unless is_storage_ng;

        # in last step of for loop edit first vda1 and format it as EFI ESP, preparation for fate#322485
        if ($_ eq 'vdd' and get_var('UEFI')) {
            assert_screen 'partitioning_raid-disk_vdd_with_partitions-selected';
            # fold the drive tree
            # Have to press to navigate in the system view tree
            send_key 'down' if is_storage_ng;
            send_key_until_needlematch 'partitioning_raid-hard_disks-unfolded', 'left';
            # select first disk
            send_key 'right';
            send_key_until_needlematch "partitioning_raid-disk_vda-selected", "down";
            # edit first partition
            send_key 'alt-e';
            assert_screen 'partition-format';
            # format as FAT (first choice) unless storage-ng
            send_key 'alt-a';
            if (is_storage_ng) {
                send_key 'alt-f';
                send_key_until_needlematch 'partitioning_raid-format_fat_UEFI', 'down';
            }
            else {
                assert_screen 'partitioning_raid-format_fat_UEFI';
            }
            # mount point selection
            send_key 'alt-o';
            assert_screen 'partitioning_raid-mount_point-focused';
            # enter mount point
            type_string '/boot/efi';
            assert_screen 'partitioning_raid-mount_point_boot_efi';
            send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
            assert_screen 'expert-partitioner';
        }

        # select next disk
        send_key "shift-tab" unless is_storage_ng;
        send_key "shift-tab" unless is_storage_ng;
    }

    # select RAID add
    send_key_until_needlematch 'partitioning_raid-raid-selected', 'down';

    send_key $cmd{addraid};

    assert_screen 'partitioning_raid-menu_add_raid';
    setraidlevel(get_var("RAIDLEVEL"));
    assert_screen 'partitioning_raid-raid_' . get_var("RAIDLEVEL") . '-selected';

    if (!get_var('UEFI')) {    # start at second partition (i.e. sda2) but not for UEFI
        send_key 'down';
        assert_screen 'partitioning_raid-devices_second_partition';
    }

    if (get_var('UEFI')) {
        addraid(2, 6);
    }
    else {
        addraid(3, 6);
    }

    assert_screen 'partition-format';
    # device must be mounted manually on SLE15
    send_key 'alt-o' if is_storage_ng;
    if (get_var('LVM')) {
        send_key $cmd{donotformat};    # 'Operating System' role to 'Raw Volume' for LVM
        assert_screen 'partitioning_raid-format_noformat';
        send_key 'alt-u';
    }

    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});

    send_key_until_needlematch('partitioning_raid-raid-selected', 'down') if is_storage_ng;    # go back to raid entry

    if (get_var('LVM')) {
        assert_screen 'partitioning_raid-raid_noformat_added';
    }
    else {
        assert_screen 'partitioning_raid-raid_btrfs_added';
    }

    if (!get_var('UEFI')) {
        # select RAID add
        send_key $cmd{addraid};
        assert_screen 'partitioning_raid-menu_add_raid';
        setraidlevel(1);
        assert_screen 'partitioning_raid-raid_1-selected';
        if (get_var('OFW')) {
            # verify that start at first partition for PowerPC
            send_key 'down';
            send_key 'up';
            assert_screen 'partitioning_raid-devices_first_partition';
        }
        addraid(2);

        assert_screen 'partition-format';
        send_key $cmd{filesystem};
        assert_screen 'partitioning_raid-filesystem-focused';
        send_key 'down';
        if (is_storage_ng) {
            # Needle matches ext2 and ext3, so select from initial position
            # Don't select from bottom due to bsc#1063596
            send_key 'alt-f';
            send_key_until_needlematch 'partitioning_raid-filesystem_ext4', 'up';
        }
        else {
            send_key 'home';
            send_key_until_needlematch 'partitioning_raid-filesystem_ext4', 'down';
        }
        send_key 'alt-o' if is_storage_ng;
        send_key 'alt-m';
        assert_screen 'partitioning_raid-mount_point-focused';
        type_string "/boot";
        assert_screen 'partitioning_raid-mount_point-_boot';

        send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
        if (get_var('LVM')) {
            send_key_until_needlematch 'partitioning_raid-raid_ext4_added-lvm', 'down';
        }
        else {
            send_key_until_needlematch 'partitioning_raid-raid_ext4_added', 'down';
        }
    }

    # select RAID add
    send_key $cmd{addraid};
    assert_screen 'partitioning_raid-menu_add_raid';
    setraidlevel(0);    # RAID0 for swap
    assert_screen 'partitioning_raid-raid_0-selected';
    addraid(1);

    # select file-system
    assert_screen 'partition-format';
    send_key $cmd{filesystem};
    assert_screen 'partitioning_raid-filesystem-focused';
    send_key_until_needlematch 'partitioning_raid-swap_format-selected', 'down';
    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
    my %needle_raid_swap_added_suffixes = (
        lvm      => '-lvm',
        uefi     => '',
        lvm_uefi => '-lvm-UEFI'
    );
    my $needle_suffix = '';
    if (get_var('LVM') && get_var('UEFI')) {
        $needle_suffix = $needle_raid_swap_added_suffixes{lvm_uefi};

    }
    elsif (get_var('LVM')) {
        $needle_suffix = $needle_raid_swap_added_suffixes{lvm};
    }
    else {
        $needle_suffix = $needle_raid_swap_added_suffixes{uefi};
    }
    send_key_until_needlematch 'partitioning_raid-raid_swap_added' . $needle_suffix, 'down';

    # LVM on top of raid if needed
    if (get_var("LVM")) {
        set_lvm();
        save_screenshot;
    }

    # done
    send_key $cmd{accept};

    # accept 8GB disk space with snapshots in RAID test fate#320416
    if (check_screen 'partition-small-for-snapshots', 5) {
        send_key 'alt-y';
    }
    # skip subvolumes shadowed warning
    if (check_screen 'subvolumes-shadowed', 5) {
        send_key 'alt-y';
    }
    # check overview page for Suggested partitioning
    if (get_var("LVM") and !get_var("UEFI")) {
        assert_screen 'acceptedpartitioningraidlvm';
    }
    elsif (get_var("LVM") and get_var("UEFI")) {
        assert_screen 'acceptedpartitioningraidlvmefi';
    }
    elsif (get_var("UEFI") and !get_var("LVM")) {
        assert_screen 'acceptedpartitioningraidefi';
    }
    else {
        assert_screen 'acceptedpartitioning';
    }
}


1;
# vim: set sw=4 et:
