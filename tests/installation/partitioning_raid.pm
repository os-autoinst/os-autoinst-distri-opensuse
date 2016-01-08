use strict;
use warnings;
use base "y2logsstep";
use testapi;

# add a new primary partition
#   $type == 3 => 0xFD Linux RAID
sub addpart($) {
    my ($size) = @_;
    assert_screen "expert-partitioner", 10;
    send_key $cmd{addpart};
    assert_screen "partitioning-type", 5;
    send_key $cmd{"next"};

    assert_screen "partition-size", 5;

    for (1 .. 10) {
        send_key "backspace";
    }
    type_string $size . "mb";
    assert_screen "partition-size", 3;
    send_key $cmd{"next"};
    assert_screen 'partition-role', 6;
    send_key "alt-a";    # Raw Volume
    send_key $cmd{"next"};
    assert_screen 'partition-format', 8;
    send_key $cmd{"donotformat"};
    send_key "tab";

    while (!check_screen("partition-selected-raid-type", 1)) {
        wait_screen_change {
            send_key "down";
        } || die "last item";
    }
    send_key $cmd{finish};
}

sub addraid($;$) {
    my ($step, $chunksize) = @_;
    send_key "spc";
    for (1 .. 3) {
        for (1 .. $step) {
            send_key "ctrl-down";
        }
        send_key "spc";
    }

    # add
    send_key $cmd{"add"};
    wait_idle 3;
    send_key $cmd{"next"};
    wait_idle 3;

    # chunk size selection
    if ($chunksize) {
        type_string "\t$chunksize";
    }
    send_key $cmd{"next"};
    assert_screen 'partition-role', 6;
    if ($step == 3 and get_var("LVM")) {
        send_key "alt-a";    # Raw Volume
    }
    else {
        send_key "alt-o";    # Operating System
    }
    send_key $cmd{"next"};

    wait_idle 3;
}

sub setraidlevel($) {
    my $level = shift;
    my %entry = (0 => 0, 1 => 1, 5 => 5, 6 => 6, 10 => 'g');
    send_key "alt-$entry{$level}";

    send_key "alt-i";        # move to RAID name input field
    send_key "tab";          # skip RAID name input field
}

sub set_lvm() {
    send_key "shift-tab";
    # select LVM
    send_key "down";

    # create volume group
    send_key "alt-d";
    send_key "down";
    send_key "ret";

    assert_screen 'lvmsetupraid', 6;
    # add all unformated lvm devices
    send_key "alt-d";

    # set volume name
    send_key "alt-v";
    type_string "root";
    assert_screen 'volumegroup-name-root', 5;

    send_key $cmd{"finish"}, 1;

    # create logical volume
    send_key "alt-d";
    send_key "down";
    send_key "down";
    send_key "ret";

    # create normal volume with name root
    type_string "root";
    assert_screen 'volume-name-root', 5;
    send_key $cmd{"next"};

    # keep default
    send_key $cmd{"next"};

    send_key "alt-o";    # Operating System
    send_key $cmd{"next"};

    # keep deafult to mount as root and btrfs
    send_key $cmd{finish};
    wait_idle 4;
}

sub run() {

    # create partitioning
    send_key $cmd{createpartsetup};
    assert_screen 'createpartsetup', 3;

    # user defined
    send_key $cmd{custompart};
    send_key $cmd{"next"}, 1;
    assert_screen 'custompart', 9;

    send_key "tab";
    send_key "down";    # select disks
    if (get_var("OFW")) {    ## no RAID /boot partition for ppc
        send_key 'alt-p';
        assert_screen 'partitioning-type', 5;
        send_key 'alt-n';
        assert_screen 'partitioning-size', 5;
        send_key 'ctrl-a';
        type_string "200 MB";
        send_key 'alt-n';
        assert_screen 'partition-role', 6;
        send_key "alt-a";    # Raw Volume
        send_key 'alt-n';
        assert_screen 'partition-format', 5;
        send_key 'alt-d';
        send_key 'alt-i';
        send_key_until_needlematch 'filesystem-prep', 'down';
        send_key 'ret';
        send_key 'alt-f';
        assert_screen 'custompart', 9;
        send_key 'alt-s';
        send_key 'right';
        send_key 'down';     #should select first disk'
        wait_idle 5;
    }
    else {
        send_key "right";    # unfold disks
        send_key "down";     # select first disk
        wait_idle 5;
    }

    for (1 .. 4) {
        addpart(300);        # boot
        addpart(8000);       # root
        addpart(100);        # swap
        assert_screen 'raid-partition', 15;

        # select next disk
        send_key "shift-tab";
        send_key "shift-tab";

        # walk through sub-tree
        send_key "down";
    }

    # select RAID add
    send_key $cmd{addraid};
    wait_idle 4;

    setraidlevel(get_var("RAIDLEVEL"));
    send_key "down";    # start at second partition (i.e. sda2)
                        # in this case, press down key doesn't move to next one but itself
    addraid(3, 6);

    send_key $cmd{"finish"};
    wait_idle 3;

    # select RAID add
    send_key $cmd{addraid};
    wait_idle 4;
    setraidlevel(1);    # RAID 1 for /boot
    addraid(2);

    send_key "alt-s";    # change filesystem to FAT for /boot
    for (1 .. 3) {
        send_key "down";    # select Ext4
    }

    send_key $cmd{"mountpoint"};
    for (1 .. 3) {
        send_key "down";
    }
    send_key $cmd{"finish"};

    wait_idle 3;

    # select RAID add
    send_key $cmd{addraid};
    wait_idle 4;
    setraidlevel(0);    # RAID 0 for swap
    addraid(1);

    # select file-system
    send_key $cmd{filesystem};
    send_key "end";     # swap at end of list
    send_key $cmd{"finish"};
    wait_idle 3;

    # LVM on top of raid if needed
    if (get_var("LVM")) {
        set_lvm();
    }

    # done
    send_key $cmd{"accept"};

    # skip subvolumes shadowed warning
    if (check_screen 'subvolumes-shadowed', 5) {
        send_key 'alt-y';
    }

    if (get_var("LVM")) {
        assert_screen 'acceptedpartitioningraidlvm', 6;
    }
    else {
        assert_screen 'acceptedpartitioning', 6;
    }
}


1;
# vim: set sw=4 et:
