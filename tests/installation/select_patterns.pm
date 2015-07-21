use base "y2logsstep";
use strict;
use testapi;

sub accept3rdparty {
    #Third party licenses sometimes appear
    while ( my $ret = check_screen( [qw/3rdpartylicense automatic-changes inst-overview/] ), 15 ){
            last if $ret->{needle}->has_tag("automatic-changes");
            last if $ret->{needle}->has_tag("inst-overview");
            send_key $cmd{acceptlicense}, 1;
    }
}

sub movedownelseend {
    my $ret = wait_screen_change {
        send_key 'down';
    };
    # down didn't change the screen, so exit here
    last if (!$ret);
}

sub run {
    my $self = shift;

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';
        assert_screen 'inst-overview-options', 3;
        send_key 'alt-s';
    }
    else {
        send_key_until_needlematch 'packages-section-selected', 'tab';
        send_key 'ret';
    }

    if (check_screen('dependancy-issue', 10) && get_var("WORKAROUND_DEPS")) {
        while ( check_screen 'dependancy-issue', 5 ) {
            if (check_var('VIDEOMODE', 'text')) {
                send_key 'alt-s', 3;
            }
            else {
                send_key 'alt-1', 3;
            }
            send_key 'spc', 3;
            send_key 'alt-o', 3;
        }
    }

    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-f';
        for ( 1 .. 4 ) { send_key 'up'; }
        send_key 'ret';
        assert_screen 'patterns-list-selected', 5;
    }
    else {
        send_key 'tab';
        send_key ' ', 2;
        assert_screen 'patterns-list-selected', 5;
    }

    my %wanted_patterns;
    for my $p (split(/,/, get_var('PATTERNS'))) {
        $wanted_patterns{$p} = 1;
    }

    my $counter = 70;
    while (1) {
        die "looping for too long" unless ($counter--);
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

        my $selected = check_screen([qw(current-pattern-selected on-category)], 0);
        if ($selected && $selected->{needle}->has_tag('on-category')) {
            movedownelseend;
            next;
        }
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
        movedownelseend;
    }

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a'; # accept
        accept3rdparty;
        assert_screen 'automatic-changes', 4;
        send_key 'alt-o'; # OK
    }
    else {
        send_key 'alt-o';
        accept3rdparty;
    }
    assert_screen 'inst-overview', 15;
}

1;
# vim: set sw=4 et:
