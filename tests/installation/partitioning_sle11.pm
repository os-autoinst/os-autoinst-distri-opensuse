# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self = shift;

    assert_screen 'inst-overview';
    send_key $cmd{change};
    send_key 'p';    # partitioning

    if (get_var('LVM')) {
        assert_screen 'preparing-disk';
        send_key 'alt-1';
        send_key $cmd{"next"};
        assert_screen 'preparing-disk-installing';
        send_key 'alt-l', 1;    #to use lvm
        if (get_var('ENCRYPT')) {
            send_key "alt-y", 1;
            assert_screen "inst-encrypt-password-prompt";
            type_password;
            send_key "tab";
            type_password;
            send_key "ret", 1;
        }
        send_key $cmd{"next"};
        assert_screen 'inst-overview';
    }

    if (check_var("FILESYSTEM", "btrfs") || get_var("BOO910346")) {
        assert_screen 'preparing-disk';
        send_key 'alt-1';
        send_key $cmd{"next"};
        assert_screen 'preparing-disk-installing';
        send_key 'alt-u';    #to use btrfs
        send_key $cmd{"next"};
        assert_screen 'inst-overview';
    }

    if (!check_var("FILESYSTEM", "btrfs") && get_var("BOO910346")) {

        send_key $cmd{change};
        send_key 'p';        # partitioning
        assert_screen 'preparing-disk';
        send_key 'alt-c';
        send_key $cmd{"next"};
        assert_screen 'expert-partitioning';
        send_key 'down';
        send_key 'down';
        send_key 'right';
        send_key 'down';     #should select first disk'
        send_key 'right';
        send_key 'down';     #should be boot
        send_key 'down';     #should be swap
        send_key 'down';     #should be root partition
        assert_screen 'on-root-partition';
        send_key 'alt-e';    #got to actually edit
        assert_screen 'editing-root-partition';
        send_key 'alt-s';    #goto filesystem list
        send_key ' ';        #open filesystem list
        send_key 'home';     #go to top of the list

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
                send_key 'alt-a';
                assert_screen('inst-overview');
                last;
            }
        }
    }

    if (!check_var("FILESYSTEM", "btrfs") && !get_var("BOO910346") && !get_var('LVM')) {

        assert_screen 'preparing-disk';
        send_key 'alt-c';
        send_key $cmd{"next"};
        assert_screen 'expert-partitioning';
        send_key 'down';
        send_key 'down';
        send_key 'right';
        send_key 'down';    #should select first disk'
        if (get_var("OFW")) {
            send_key 'alt-d';
            assert_screen 'add-partition';
            send_key 'alt-n';
            assert_screen 'add-partition-size';
            send_key 'ctrl-a';
            type_string "200 MB";
            send_key 'alt-n';
            assert_screen 'add-partition-type';
            send_key 'alt-d';    # goto nonfs types
            send_key 'alt-i';
            my $prep_counter = 20;
            while (1) {
                my $ret = wait_screen_change {
                    send_key 'down';
                };
                die "looping for too long/PReP not found" if (!$ret || $prep_counter-- == 0);
                if (check_screen("filesystem-prep", 1)) {
                    send_key 'ret';
                    assert_screen('expert-partitioning');
                    last;
                }
            }
        }
        send_key 'alt-d';
        assert_screen 'add-partition';
        send_key 'alt-n';
        assert_screen 'add-partition-size';
        send_key 'ctrl-a';
        type_string "1 GB";
        send_key 'alt-n';
        assert_screen 'add-partition-type';
        send_key 'alt-s';    #goto filesystem list
        send_key ' ';        #open filesystem list
        send_key 'home';     #go to top of the list

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
                assert_screen('expert-partitioning');
                last;
            }
        }

        send_key 'alt-d';
        assert_screen 'add-partition';
        send_key 'alt-n';
        assert_screen 'add-partition-size';
        send_key 'ctrl-a';
        type_string "300 MB";
        send_key 'alt-n';
        assert_screen 'add-partition-type';
        send_key 'alt-m';    #goto mount point
        type_string "/boot";
        send_key 'alt-f';
        assert_screen('expert-partitioning');

        send_key 'alt-d';
        assert_screen 'add-partition';
        send_key 'alt-n';
        assert_screen 'add-partition-size';
        send_key 'alt-n';
        assert_screen 'add-partition-type';
        send_key 'alt-s';    #goto filesystem list
        send_key ' ';        #open filesystem list
        send_key 'home';     #go to top of the list

        my $counter2 = 20;
        while (1) {
            my $ret = wait_screen_change {
                send_key 'down';
            };
            # down didn't change the screen, so exit here
            die "looping for too long/filesystem not found" if (!$ret || $counter2-- == 0);

            my $fs = get_var('FILESYSTEM');

            if (check_screen("filesystem-$fs", 1)) {
                send_key 'ret';
                send_key 'alt-f';
                assert_screen('expert-partitioning');
                last;
            }
        }

        send_key 'alt-a';
        assert_screen('inst-overview');
    }
}



1;
# vim: set sw=4 et:
