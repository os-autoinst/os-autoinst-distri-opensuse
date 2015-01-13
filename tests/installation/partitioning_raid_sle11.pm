#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub key_round($$) {
    my ($tag, $key) = @_;

    my $counter = 10;
    while ( !check_screen( $tag, 1 ) ) {
        send_key $key;
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

sub addraid($) {
    my ($step) = @_;
    send_key "spc";
    for ( 1 .. 3 ) {
        for ( 1 .. $step ) {
            send_key "ctrl-down";
        }

        # in GNOME Live case, press space will direct added this item
        if ( get_var("GNOME") ) {
            send_key "ctrl-spc";
        }
        else {
            send_key "spc";
        }
    }

    # add
    send_key $cmd{"add"};
    wait_idle 3;
    send_key $cmd{"next"};
    wait_idle 3;

    # chunk size selection
    send_key "alt-c";
    send_key "home";
    for ( 1 .. 4 ) {
        send_key "down";
    }

    send_key $cmd{"next"};
    assert_screen 'partition-role', 6;
    send_key "alt-o";    # Operating System
    send_key $cmd{"next"};
    wait_idle 3;
}

sub setraidlevel($) {
    my $level = shift;
    my %entry = ( 0 => 0, 1 => 1, 5 => 5, 6 => 6, 10 => 'i' );
    send_key "alt-$entry{$level}";
}

sub run() {

    assert_screen 'inst-overview', 10;
    send_key $cmd{change};
    send_key 'p'; # partitioning

    assert_screen 'preparing-disk', 5;
    send_key 'alt-c';
    send_key $cmd{"next"};
    assert_screen 'expert-partitioning', 5;
    send_key 'down';
    send_key 'down';
    send_key 'right';
    send_key 'down'; #should select first disk'

    for ( 1 .. 4 ) {
        send_key 'alt-d';
        assert_screen 'add-partition', 5;
        send_key 'alt-n';
        assert_screen 'add-partition-size', 5;
        send_key 'ctrl-a';
        type_string "1 GB";
        send_key 'alt-n';
        assert_screen 'add-partition-type', 5;
        send_key 'alt-d'; #Do not format partition
        send_key 'alt-i'; #Filesystem ID
        send_key 'down';
        send_key 'down';
        send_key 'down'; #Linux RAID System Type
        send_key 'alt-f';
        assert_screen('expert-partitioning', 5);

        send_key 'alt-d';
        assert_screen 'add-partition', 5;
        send_key 'alt-n';
        assert_screen 'add-partition-size', 5;
        send_key 'ctrl-a';
        type_string "300 MB";
        send_key 'alt-n';
        assert_screen 'add-partition-type', 5;
        send_key 'alt-d'; #Do not format partition
        send_key 'alt-i'; #Filesystem ID
        send_key 'down';
        send_key 'down';
        send_key 'down'; #Linux RAID System Type
        send_key 'alt-f';
        assert_screen('expert-partitioning', 5);

        send_key 'alt-d';
        assert_screen 'add-partition', 5;
        send_key 'alt-n';
        assert_screen 'add-partition-size', 5;
        send_key 'alt-n';
        assert_screen 'add-partition-type', 5;
        send_key 'alt-d'; #Do not format partition
        send_key 'alt-i'; #Filesystem ID
        send_key 'down';
        send_key 'down';
        send_key 'down'; #Linux RAID System Type
        send_key 'alt-f';
        assert_screen('expert-partitioning', 5);

        # select next disk
        send_key "shift-tab";
        send_key "shift-tab";
        send_key "down";

    }

    # select RAID add
    send_key 'alt-i';
    assert_screen('add-raid', 5);
    setraidlevel( get_var("RAIDLEVEL") );
    key_round 'raid-devices-selected', 'tab';
    send_key "down";
    send_key "down"; # start at second partition (i.e. sda2)
    for ( 1 .. 3 ) {
        for ( 1 .. 3 ) {
            send_key "ctrl-down";
            send_key "spc";
        }
    }
    # add
    send_key $cmd{"add"};
    wait_idle 3;
    send_key $cmd{"next"};
    wait_idle 3;

    send_key $cmd{"next"};
    assert_screen 'add-partition-type', 6;
    send_key 'alt-f';
    wait_idle 3;

    #rbrown

    # select RAID add
    send_key $cmd{addraid};
    wait_idle 4;
    setraidlevel(1);    # RAID 1 for /boot
    addraid(2);

    send_key "alt-s";    # change filesystem to FAT for /boot
    for ( 1 .. 3 ) {
        send_key "down";    # select Ext4
    }

    send_key $cmd{"mountpoint"};
    for ( 1 .. 3 ) {
        send_key "down";
    }
    send_key $cmd{"finish"};

    # workaround for gnomelive, double alt-f available in same page
    if ( get_var("GNOME") ) {
        send_key $cmd{"finish"};
        send_key "spc";
    }
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

    # done
    send_key $cmd{"accept"};

    # skip subvolumes shadowed warning
    if ( check_screen 'subvolumes-shadowed', 5 ) {
        send_key 'alt-y';
    }
    assert_screen 'acceptedpartitioning', 6;
}


1;
# vim: set sw=4 et:
