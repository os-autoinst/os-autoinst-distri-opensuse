#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub key_round($$) {
    my ($tag, $key) = @_;

    my $counter = 15;
    while ( !check_screen( $tag, 1 ) ) {
        send_key $key;
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

sub run() {

    # overview-generation
    # this is almost impossible to check for real
    assert_screen "inst-overview", 15;

    # preserve it for the video
    wait_idle 10;

    # check for dependency issues, if found, drill down to software selection, take a screenshot, then die
    if (check_screen("inst-overview-dep-warning",1)){

        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-c';
            assert_screen 'inst-overview-options', 3;
            send_key 'alt-s';
        }
        else {
            key_round 'packages-section-selected', 'tab';
            send_key 'ret';
        }

        assert_screen 'pattern_selector';
        send_key 'alt-o';
        assert_screen 'dependancy-issue', 5;
        die "Dependency Warning Detected";
    }
}

1;
# vim: set sw=4 et:
