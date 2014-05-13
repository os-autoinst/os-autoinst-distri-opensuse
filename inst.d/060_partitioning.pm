#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$envs->{UPGRADE};
}

# add a new primary partition
#   $type == 3 => 0xFD Linux RAID
sub addpart($$) {
    my ( $size, $type ) = @_;
    send_key $cmd{addpart};
    waitidle 5;
    send_key $cmd{"next"};
    waitidle 5;

    # the input point at the head of the lineedit, move it to the end
    if ( $envs->{GNOME} ) { send_key "end" }
    for ( 1 .. 10 ) {
        send_key "backspace";
    }
    type_string  $size . "mb" ;
    waitidle 5;
    send_key $cmd{"next"};
    waitidle 5;
    send_key $cmd{"donotformat"};
    waitidle 5;
    send_key "tab";
    waitidle 5;

    for ( 1 .. $type ) {
        waitidle 5;
        send_key "down";
    }
    waitidle 5;
    send_key $cmd{finish};
}

sub addraid($;$) {
    my ( $step, $chunksize ) = @_;
    send_key "spc";
    for ( 1 .. 3 ) {
        for ( 1 .. $step ) {
            send_key "ctrl-down";
        }

        # in GNOME Live case, press space will direct added this item
        if ( $envs->{GNOME} ) {
            send_key "ctrl-spc";
        }
        else {
            send_key "spc";
        }
    }

    # add
    send_key $cmd{"add"};
    waitidle 3;
    send_key $cmd{"next"};
    waitidle 3;

    # chunk size selection
    if ($chunksize) {

        # workaround for gnomelive with chunksize 64kb
        if ( $envs->{GNOME} ) {
            send_key "alt-c";
            send_key "home";
            for ( 1 .. 4 ) {
                send_key "down";
            }
        }
        else {
            type_string "\t$chunksize";
        }
    }
    send_key $cmd{"next"};
    waitidle 3;
}

sub setraidlevel($) {
    my $level = shift;
    my %entry = ( 0 => 0, 1 => 1, 5 => 2, 6 => 3, 10 => 4 );
    for ( 0 .. $entry{$level} ) {
        send_key "tab";
    }
    send_key "spc";    # set entry
    for ( $entry{$level} .. $entry{10} ) {
        send_key "tab";
    }

    # skip RAID name input
    send_key "tab";
}

# Entry test code
sub run() {

    # XXX: yast introduced a popup instead of immediate check boxes.
    # this is a workaround to be able to deal with both old and new
    # style. Needs to go away. BTRFS and TOGGLEHOME must be ajdusted
    # to the new way.
    my $newstyle;
    my $closedialog;
    my $ret = assert_screen  [ 'partitioning', 'partioning-edit-proposal-button' ], 40 ;
    if ( $ret->{needle}->has_tag('partioning-edit-proposal-button') ) {
        $newstyle = 1;
    }

    if ( $envs->{DUALBOOT} ) {
        assert_screen  'partitioning-windows', 40 ;
    }

    # XXX: why is that here?
    if ( $envs->{TOGGLEHOME} && !$envs->{LIVECD} ) {
        my $homekey = checkEnv( 'VIDEOMODE', "text" ) ? "alt-p" : "alt-h";
        if ($newstyle) {
            send_key 'alt-d';
            $closedialog = 1;
            $homekey     = 'alt-p';
        }
        send_key $homekey;
        assert_screen  "disabledhome", 10 ;
        if ($closedialog) {
            send_key 'alt-o';
            $closedialog = 0;
        }
        waitidle 5;
    }

    if ( defined( $envs->{RAIDLEVEL} ) ) {

        # create partitioning
        send_key $cmd{createpartsetup};
        assert_screen  'createpartsetup', 3 ;

        # user defined
        send_key $cmd{custompart};
        send_key $cmd{"next"};
        assert_screen  'custompart', 9 ;

        send_key "tab";
        send_key "down";    # select disks
                           # seems GNOME tree list didn't eat right arrow key
        if ( $envs->{GNOME} ) {
            send_key "spc";    # unfold disks
        }
        else {
            send_key "right";    # unfold disks
        }
        send_key "down";         # select first disk
        waitidle 5;

        for ( 1 .. 4 ) {
            waitidle 5;
            addpart( 100, 3 );    # boot
            waitidle 5;
            addpart( 5300, 3 );    # root
            waitidle 5;
            addpart( 300, 3 );     # swap
            assert_screen  'raid-partition', 5 ;

            # select next disk
            send_key "shift-tab";
            send_key "shift-tab";

            # walk through sub-tree
            if ( $envs->{GNOME} ) {
                for ( 1 .. 3 ) { send_key "down" }
            }
            send_key "down";
        }

        # select RAID add
        send_key $cmd{addraid};
        waitidle 4;

        if ( !defined( $envs->{RAIDLEVEL} ) ) { $envs->{RAIDLEVEL} = 6 }
        setraidlevel( $envs->{RAIDLEVEL} );
        send_key "down";    # start at second partition (i.e. sda2)
                           # in this case, press down key doesn't move to next one but itself
        if ( $envs->{GNOME} ) { send_key "down" }
        addraid( 3, 6 );

        # workaround for gnomelive, double alt-f available in same page
        if ( $envs->{GNOME} ) {
            send_key "spc";
        }
        else {
            send_key $cmd{"finish"};
        }
        waitidle 3;

        # select RAID add
        send_key $cmd{addraid};
        waitidle 4;
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
        if ( $envs->{GNOME} ) {
            send_key $cmd{"finish"};
            send_key "spc";
        }
        waitidle 3;

        # select RAID add
        send_key $cmd{addraid};
        waitidle 4;
        setraidlevel(0);    # RAID 0 for swap
        addraid(1);

        # select file-system
        send_key $cmd{filesystem};
        send_key "end";      # swap at end of list
        send_key $cmd{"finish"};
        waitidle 3;

        # done
        send_key $cmd{"accept"};
        assert_screen  'acceptedpartitioning', 6 ;
    }
    elsif ( $envs->{BTRFS} ) {
        if ($newstyle) {
            send_key "alt-d";
            $closedialog = 1;
        }
        if ( !check_screen 'usebtrfs' ) {
            waitidle 3;
            if ($newstyle) {
                send_key "alt-f";
                sleep 2;
                send_key "b";    # use btrfs
            }
            else {
                send_key "alt-u";    # use btrfs
            }
        }
        sleep 3;
        assert_screen  'usebtrfs', 3 ;

        if ($closedialog) {
            send_key 'alt-o';
            $closedialog = 0;
        }
    }
}

1;
# vim: set sw=4 et:
