#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

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
    my ($level) = @_;

    my %entry = ( 0 => 0, 1 => 1, 5 => 5, 6 => 6, 10 => 'i' );
    send_key "alt-$entry{$level}";
}

sub run() {
    my ($self) = @_;

    assert_screen 'inst-overview', 10;
    send_key $cmd{change};
    send_key 'p'; # partitioning

    assert_screen 'preparing-disk', 5;
    send_key 'alt-c';
    send_key $cmd{"next"};
    assert_screen 'expert-partitioning', 5;
    send_key 'down';
    send_key 'down';
    if (get_var("OFW")) { ## no RAID /boot partition for ppc
        send_key 'alt-p';
        assert_screen 'add-partition', 5;
        send_key 'alt-n';
        assert_screen 'add-partition-size', 5;
        send_key 'ctrl-a';
        type_string "200 MB";
        send_key 'alt-n';
        assert_screen 'add-partition-type', 5;
        send_key 'alt-d';
        send_key 'alt-i';
        my $prep_counter = 20;
        while (1) {
            my $ret = wait_screen_change {
                send_key 'down';
            };

            die "looping for too long/PReP not found" if (!$ret || $prep_counter-- == 0);
            if (check_screen("filesystem-prep", 1)) {
                send_key 'ret';
                assert_screen('expert-partitioning', 5);
                last;
            }
        }
        send_key 'alt-f';
        sleep 1;
        send_key 'alt-s';
        send_key 'right';
        send_key 'down'; #should select first disk'
    }
    else {
        send_key 'right';
        send_key 'down'; #should select first disk'
    }

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

    # select RAID add for /
    send_key 'alt-i';
    assert_screen('add-raid', 5);
    setraidlevel( get_var("RAIDLEVEL") );
    send_key_until_needlematch 'raid-devices-selected', 'tab';
    send_key "down";
    send_key "down"; # start at second partition (i.e. sda2)
    for ( 1 .. 3 ) {
        for ( 1 .. 3 ) {
            send_key "ctrl-down";
        }
        send_key "spc";
    }
    # add
    send_key $cmd{"add"};
    wait_idle 3;
    send_key $cmd{"next"};
    wait_idle 3;

    send_key $cmd{"next"};
    assert_screen 'add-partition-type', 6;
    if ( get_var("FILESYSTEM")) {
        send_key 'alt-s'; #goto filesystem list
        send_key ' '; #open filesystem list
        send_key 'home'; #go to top of the list

        my $counter = 20;
        while (1) {
            my $ret = wait_screen_change {
                send_key 'down';
            };
            # down didn't change the screen, so exit here
            die "looping for too long/filesystem not found" if (!$ret || $counter-- == 0);

            my $fs = get_var('FILESYSTEM');

            if (check_screen("filesystem-$fs", 1)) {
                send_key 'ret';
                send_key 'alt-f';
                wait_idle 3;
                last;
            }
        }
    }
    else {
        send_key 'alt-f';
        wait_idle 3;
    }

    # select RAID add for /boot
    send_key 'alt-i';
    assert_screen('add-raid', 5);
    setraidlevel(1); # RAID 1 for /boot
    send_key_until_needlematch 'raid-devices-selected', 'tab';
    send_key "down"; # start at the 300MB partition
    for ( 1 .. 3 ) {
        for ( 1 .. 2 ) {
            send_key "ctrl-down";
        }
        send_key "spc";
    }
    # add
    send_key $cmd{"add"};
    wait_idle 3;
    send_key $cmd{"next"};
    wait_idle 3;

    send_key $cmd{"next"};
    assert_screen 'add-partition-type', 6;
    send_key 'alt-m'; #goto mount point
    type_string "/boot";
    send_key 'alt-f';
    wait_idle 3;

    # select RAID add for swap
    send_key 'alt-i';
    assert_screen('add-raid', 5);
    setraidlevel(0); # RAID 0 for swap
    send_key_until_needlematch 'raid-devices-selected', 'tab';
    send_key "spc"; # only 4 partitions left
    for ( 1 .. 3 ) {
        send_key "ctrl-down";
        send_key "spc";
    }
    # add
    send_key $cmd{"add"};
    wait_idle 3;
    send_key $cmd{"next"};
    wait_idle 3;

    send_key $cmd{"next"};
    assert_screen 'add-partition-type', 6;
    send_key 'alt-s'; #goto filesystem list
    send_key ' '; #open filesystem list
    send_key 'home'; #go to top of the list

    my $counter = 20;
    while (1) {
        my $ret = wait_screen_change {
            send_key 'down';
        };
        # down didn't change the screen, so exit here
        die "looping for too long/filesystem not found" if (!$ret || $counter-- == 0);

        if (check_screen("filesystem-swap", 1)) {
            send_key 'ret';
            send_key 'alt-f';
            assert_screen('expert-partitioning', 5);
            last;
        }
    }

    send_key $cmd{"accept"};

    # skip subvolumes shadowed warning
    if ( check_screen 'subvolumes-shadowed', 5 ) {
        send_key 'alt-y';
    }
    assert_screen 'acceptedpartitioning', 6;

    if ( !get_var("OFW") ) {
        #Bootloader needs to be installed to MBR
        send_key 'alt-c';
        send_key 'b';
        assert_screen 'bootloader-settings', 6;
        send_key 'alt-l';
        assert_screen 'bootloader-installation-settings', 6;
        send_key 'alt-m';
        send_key 'alt-o';
    }
    assert_screen "inst-overview", 15;
}


1;
# vim: set sw=4 et:
