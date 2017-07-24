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
    if (!get_var('UEFI')) {    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
        assert_screen "partitioning-type";
        send_key $cmd{next};
    }

    assert_screen "partition-size";

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

    if ($part eq 'boot' and get_var('UEFI')) {
        send_key_until_needlematch 'partition-selected-efi-type', 'down';
    }
    else {
        send_key_until_needlematch 'partition-selected-raid-type', 'down';
    }
    send_key $cmd{finish};
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

    send_key $cmd{next};
    wait_idle 3;
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

    # keep deafult to mount as root and btrfs
    send_key $cmd{finish};
    wait_idle 4;
}

sub run {

    # create partitioning
    send_key $cmd{createpartsetup};
    assert_screen 'createpartsetup';

    # user defined
    send_key $cmd{custompart};
    assert_screen 'custompart_option-selected';
    send_key $cmd{next};
    assert_screen 'custompart';

    send_key "tab";
    assert_screen 'custompart_systemview-selected';
    send_key "down";
    assert_screen 'partitioning_raid-hard_disks-selected';

    if (get_var("OFW")) {    ## no RAID /boot partition for ppc
        send_key 'alt-p';
        if (!get_var('UEFI')) {    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
            assert_screen 'partitioning-type';
            send_key 'alt-n';
        }
        assert_screen 'partition-size';
        wait_screen_change { send_key 'ctrl-a' };
        type_string "8 MB";
        send_key 'alt-n';
        assert_screen 'partition-role';
        send_key "alt-a";
        assert_screen 'partitioning_raid-partition_role_raw_volume';
        send_key 'alt-n';
        assert_screen 'partition-format';
        send_key 'alt-d';
        assert_screen 'partitioning_raid-format_noformat';
        send_key 'alt-i';
        assert_screen 'partitioning_raid-file_system_id-selected';
        send_key_until_needlematch 'filesystem-prep', 'down';
        send_key 'alt-f';
        assert_screen 'partitioning_raid-added_prep';
        send_key 'alt-s';
        send_key 'right';
        assert_screen 'partitioning_raid-hard_disks-unfolded';
        send_key 'down';
        assert_screen 'partitioning_raid-disk_vda-selected';
    }
    else {
        send_key "right";
        assert_screen 'partitioning_raid-hard_disks-unfolded';
        send_key "down";
        assert_screen 'partitioning_raid-disk_vda-selected';
    }

    for (1 .. 4) {
        if (!get_var('OFW')) {
            # add raid boot partition except for PowerPC
            addpart('boot');
            assert_screen 'partitioning_raid-part_boot_added';
        }
        addpart('root');
        assert_screen 'partitioning_raid-part_root_added';
        addpart('swap');
        assert_screen 'raid-partition';

        # select next disk
        send_key "shift-tab";
        send_key "shift-tab";

        # in last step of for loop edit first vda1 and format it as EFI ESP, preparation for fate#322485
        if ($_ == 4 and get_var('UEFI')) {
            assert_screen 'partitioning_raid-disk_vdd_with_partitions-selected';
            send_key 'left';    # fold the drive tree
            assert_screen 'partitioning_raid-hard_disks-unfolded';
            send_key 'right';    # select first disk
            assert_screen 'partitioning_raid-disk_vda_with_partitions-selected';
            send_key 'alt-e';    # edit first partition
            assert_screen 'partition-format';
            send_key 'alt-a';    # format as FAT (first choice)
            assert_screen 'partitioning_raid-format_fat_UEFI';
            send_key 'alt-o';    # mount point selection
            assert_screen 'partitioning_raid-mount_point-focused';
            type_string '/boot/efi';    # enter mount point
            assert_screen 'partitioning_raid-mount_point_boot_efi';
            send_key $cmd{finish};
            assert_screen 'expert-partitioner';
            send_key 'shift-tab';
            send_key 'shift-tab';
            send_key 'left';            # go to top "Hard Disks" node
            assert_screen 'partitioning_raid-hard_disks-unfolded';
            send_key 'left';            # fold the drive tree again
        }

        # walk through sub-tree
        send_key "down";
        if ($_ < 4) {
            my %selection_to_disk = (
                1 => 'vdb',
                2 => 'vdc',
                3 => 'vdd'
            );
            assert_screen 'partitioning_raid-disk_' . $selection_to_disk{$_} . '-selected';
        }
    }

    # select RAID add
    assert_screen 'partitioning_raid-raid-selected';
    send_key $cmd{addraid};

    assert_screen 'partitioning_raid-menu_add_raid';
    setraidlevel(get_var("RAIDLEVEL"));
    assert_screen 'partitioning_raid-raid_' . get_var("RAIDLEVEL") . '-selected';

    if (!get_var('UEFI') && !get_var('OFW')) {
        # start at second partition (i.e. sda2) except if UEFI or PowerPC
        send_key 'down';
        assert_screen 'partitioning_raid-devices_second_partition';
        addraid(3, 6);
    }
    else {
        addraid(2, 6);
    }

    assert_screen 'partition-format';
    if (get_var('LVM')) {
        send_key $cmd{donotformat};    # 'Operating System' role to 'Raw Volume' for LVM
        assert_screen 'partitioning_raid-format_noformat';
        send_key 'alt-u';
    }

    send_key $cmd{finish};
    if (get_var('LVM')) {
        assert_screen 'partitioning_raid-raid_noformat_added';
    }
    else {
        assert_screen 'partitioning_raid-raid_btrfs_added';
    }

    if (!get_var('UEFI') && !get_var('OFW')) {
        # select RAID for /boot except if UEFI or PowerPC
        send_key $cmd{addraid};
        assert_screen 'partitioning_raid-menu_add_raid';
        setraidlevel(1);
        assert_screen 'partitioning_raid-raid_1-selected';
        addraid(2);

        assert_screen 'partition-format';
        send_key "alt-s";
        assert_screen 'partitioning_raid-filesystem-focused';
        send_key 'down' for (1 .. 3);
        assert_screen 'partitioning_raid-filesystem_ext4';
        send_key "alt-m";
        assert_screen 'partitioning_raid-mount_point-focused';
        type_string "/boot";
        assert_screen 'partitioning_raid-mount_point-_boot';

        send_key $cmd{finish};
        if (get_var('LVM')) {
            assert_screen 'partitioning_raid-raid_ext4_added-lvm';
        }
        else {
            assert_screen 'partitioning_raid-raid_ext4_added';
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
    send_key "end";
    assert_screen 'partitioning_raid-swap_format-selected';
    send_key $cmd{finish};
    my %needle_raid_swap_added_suffixes = (
        ofw      => '-no_boot',
        lvm      => '-lvm',
        uefi     => '',
        lvm_uefi => '-lvm-UEFI'
    );
    my $needle_suffix = '';
    if (get_var('OFW')) {
        $needle_suffix = $needle_raid_swap_added_suffixes{ofw};
    }
    elsif (get_var('LVM') && get_var('UEFI')) {
        $needle_suffix = $needle_raid_swap_added_suffixes{lvm_uefi};

    }
    elsif (get_var('LVM')) {
        $needle_suffix = $needle_raid_swap_added_suffixes{lvm};
    }
    else {
        $needle_suffix = $needle_raid_swap_added_suffixes{uefi};
    }
    assert_screen 'partitioning_raid-raid_swap_added' . $needle_suffix;

    # LVM on top of raid if needed
    if (get_var("LVM")) {
        set_lvm();
        wait_idle 3;
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
    if (get_var('OFW')) {
        assert_screen 'acceptedpartitioningraid-no_boot';
    }
    elsif (get_var("LVM") and !get_var("UEFI")) {
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
