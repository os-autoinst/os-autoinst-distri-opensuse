use base "y2logsstep";
use strict;
use testapi;

sub key_round($$) {
    my ($tag, $key) = @_;

    my $counter = 10;
    while ( !check_screen( $tag, 1 ) ) {
        wait_screen_change {
            send_key $key;
        };
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

sub run {
    my $self = shift;

    # ncurses offers a faster way
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
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-f';
        for ( 1 .. 4 ) { send_key 'up'; }
        send_key 'ret';
        assert_screen 'patterns-list-selected', 5;
        send_key 'tab';
    }
    else {
        key_round 'patterns-list-selected', 'tab';
    }

    if (!check_var('DESKTOP', 'gnome')) {
        key_round('gnome-selected', 'down');
        wait_screen_change { send_key ' '; };
    }
    if (check_var('DESKTOP', 'kde')) {
        key_round('kde-unselected', 'down');
        wait_screen_change { send_key ' '; };
    }
    if (check_var('DESKTOP', 'textmode')) {
        key_round('x11-selected', 'down');
        wait_screen_change { send_key ' '; };
    }

    assert_screen "desktop-selected", 5;

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a'; # accept
        assert_screen 'automatic-changes', 4;
        send_key 'alt-o'; # OK
    }
    else {
        send_key 'alt-o'; # OK
    }
    assert_screen "inst-overview", 15;

}

1;
# vim: set sw=4 et:
