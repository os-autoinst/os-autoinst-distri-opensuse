use base "y2logsstep";
use strict;
use testapi;

sub key_round($$) {
    my ($tag, $key) = @_;

    my $counter = 10;
    while ( !check_screen( $tag, 1 ) ) {
        send_key $key;
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

sub run {
    my $self = shift;

    key_round 'packages-section-selected', 'tab';
    send_key 'ret';

    assert_screen 'pattern_selector';
    key_round 'patterns-list-selected', 'tab';

    if (!check_var('DESKTOP', 'gnome')) {
        key_round('gnome-selected', 'down');
        send_key ' ';
    }
    if (check_var('DESKTOP', 'kde')) {
        key_round('kde-unselected', 'down');
        send_key ' ';
    }
    if (check_var('DESKTOP', 'textmode')) {
        key_round('x11-selected', 'down');
        send_key ' ';
    }

    assert_screen "desktop-selected", 5;

    send_key 'alt-o';
    assert_screen "inst-overview", 15;

}

1;
# vim: set sw=4 et:
