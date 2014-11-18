#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use bmwqemu;

sub run() {
    send_key "alt-d";
    my $closedialog = 1;
    assert_screen "partition-proposals-window", 5;
    if ( !check_screen 'usebtrfs', 3 ) {
        send_key "alt-f";
        sleep 2;
        send_key "b";    # use btrfs
    }
    sleep 3;
    assert_screen 'usebtrfs', 3;

    if ($closedialog) {
        send_key 'alt-o';
        $closedialog = 0;
    }
}

1;
# vim: set sw=4 et:
