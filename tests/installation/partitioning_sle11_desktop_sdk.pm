use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self = shift;

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
    send_key 'alt-d';
    assert_screen 'add-partition', 5;
    send_key 'alt-n';
    assert_screen 'add-partition-size', 5;
    send_key 'ctrl-a';
    type_string "1 GB";
    send_key 'alt-n';
    assert_screen 'add-partition-type', 5;
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

    send_key 'alt-d';
    assert_screen 'add-partition', 5;
    send_key 'alt-n';
    assert_screen 'add-partition-size', 5;
    send_key 'ctrl-m';
    send_key 'alt-n';
    assert_screen 'add-partition-type', 5;
    send_key 'alt-f';
    assert_screen('expert-partitioning', 5);

    send_key 'alt-a';
    assert_screen('inst-overview', 30);

}



1;
# vim: set sw=4 et:
