#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    send_key "alt-e", 1; # Expert
    send_key "alt-e", 1; # Rescan
    send_key "alt-s"; # System View
    send_key "down";  # select Disk
    send_key "alt-p", 1; # Add Partition
    send_key "ret", 1; # Primary
    send_key "ret", 1; # Size
    send_key "alt-a", 1; # Raw
    send_key "ret", 1; # Raw
    send_key "ret", 1; # Finish

    send_key "alt-s", 1; # System View
    send_key "down";
    send_key "down";  # select Volume Management
    send_key "alt-d", 1; # Add
    send_key "ret", 1;
    send_key "ret", 1; # VG
    type_string "system";
    send_key "alt-d", 1; # Add All
    send_key "ret", 1; # Finish

    send_key "alt-s", 1; # System View
    send_key "right", 1;
    send_key "down", 1;  # select VG

    send_key "alt-d", 1; # Add
    type_string "swap\n";
    wait_idle(1);
    send_key "alt-c", 1; # Custom Size
    type_string "0.2G\n";
    wait_idle(1);
    send_key "alt-s", 1; # Swap
    send_key "ret", 1; # Next
    send_key "ret", 1; # Finish

    send_key "alt-d", 1; # Add
    type_string "root\n";
    wait_idle(1);
    send_key "ret", 1; # Size
    send_key "alt-o", 1; # Operating System
    send_key "ret", 1; # Next
    send_key "ret", 1; # Finish

    assert_screen "partition-lvm-manual-summary", 3;
    send_key "alt-a", 1; # Accept
}

1;
# vim: set sw=4 et:
