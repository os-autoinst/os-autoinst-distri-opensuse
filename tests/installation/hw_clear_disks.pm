#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;
    wait_still_screen(30, 290);

    #send_key "ctrl-alt-shift-x"; sleep 3;
    send_key "ctrl-alt-f2";
    sleep 3;
    my $disks = $bmwqemu::backend->{'hardware'}->{'disks'};
    for my $disk (@$disks) {
        type_string "wipefs -a $disk\n";
        sleep 1;
        type_string "dd if=/dev/zero of=$disk bs=1M count=1\n";
        sleep 2;
        type_string "blockdev --rereadpt $disk\n";
        sleep 4;
    }
    wait_still_screen;
    assert_screen 'test-hw_clear_disks-1', 3;

    #send_key "ctrl-d"; sleep 3;
    my $instcon = (check_var("VIDEOMODE", "text")) ? 1 : 7;
    send_key "ctrl-alt-f$instcon";
    sleep 3;
}

1;
# vim: set sw=4 et:
