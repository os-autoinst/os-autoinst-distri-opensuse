use base "y2logsstep";
use testapi;

# the test won't work atm
sub run() {
    my $homekey = check_var('VIDEOMODE', "text") ? "alt-p" : "alt-h";
    send_key 'alt-d';
    $closedialog = 1;
    $homekey     = 'alt-p';
    assert_screen "partition-proposals-window", 5;
    send_key $homekey;
    for (1 .. 3) {
        if (!check_screen "disabledhome", 8) {
            send_key $homekey;
        }
        else {
            last;
        }
    }
    assert_screen "disabledhome", 5;
    if ($closedialog) {
        send_key 'alt-o';
        $closedialog = 0;
    }
    wait_idle 5;
}

1;
# vim: set sw=4 et:
