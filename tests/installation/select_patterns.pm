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

    my %wanted_patterns;
    for my $p (split(/,/, get_var('PATTERNS'))) {
        $wanted_patterns{$p} = 1;
    }

    my $counter = 50;
    while (!check_screen('at-the-last-pattern', 1)) {
        send_key 'down';
        sleep 1; # see https://progress.opensuse.org/issues/5482
        last unless ($counter--);
        my $needs_to_be_selected;
        my $ret = check_screen('on-pattern', 1);

        if ($ret) { # unneedled pattern
            for my $wp (keys %wanted_patterns) {
                if ($ret->{needle}->has_tag("pattern-$wp")) {
                    $needs_to_be_selected = 1;
                }
            }
        }
        $needs_to_be_selected=1 if ($wanted_patterns{'all'});

        my $selected = check_screen([qw(current-pattern-selected on-category)], 1);
        next if ($selected && $selected->{needle}->has_tag('on-category'));

        if ($needs_to_be_selected && !$selected) {
            send_key ' ';
            assert_screen 'current-pattern-selected', 2;
        }
        elsif (!$needs_to_be_selected && $selected) {
            send_key ' ';
            assert_screen [qw(current-pattern-unselected current-pattern-autoselected)], 2;
        }
    }

    send_key 'alt-o';
    assert_screen "inst-overview", 15;
}

1;
# vim: set sw=4 et:
