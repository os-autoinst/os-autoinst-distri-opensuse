use base "y2logsstep";
use strict;
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

sub run {
    my $self = shift;

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
    
    my %wanted_patterns;
    for my $p (split(/,/, get_var('PATTERNS'))) {
        $wanted_patterns{$p} = 1;
    }

    my $counter = 70;
    while (1) {
        my $ret = wait_screen_change {
            send_key 'down';
        };
        # down didn't change the screen, so exit here
        last if (!$ret);

        die "looping for too long" unless ($counter--);
        my $needs_to_be_selected;
        $ret = check_screen('on-pattern', 1);

        if ($ret) { # unneedled pattern
            for my $wp (keys %wanted_patterns) {
                if ($ret->{needle}->has_tag("pattern-$wp")) {
                    $needs_to_be_selected = 1;
                }
            }
        }
        $needs_to_be_selected=1 if ($wanted_patterns{'all'});

        my $selected = check_screen([qw(current-pattern-selected on-category)], 0);
        next if ($selected && $selected->{needle}->has_tag('on-category'));

        if ($needs_to_be_selected && !$selected) {
            wait_screen_change {
                send_key ' ';
            };
            assert_screen 'current-pattern-selected', 2;
        }
        elsif (!$needs_to_be_selected && $selected) {
            send_key ' ';
            assert_screen [qw(current-pattern-unselected current-pattern-autoselected)], 3;
        }
    }

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a'; # accept
        assert_screen 'automatic-changes', 4;
        send_key 'alt-o'; # OK
    }
    else {
        send_key 'alt-o';
    }
    assert_screen "inst-overview", 15;
}


1;
# vim: set sw=4 et:
