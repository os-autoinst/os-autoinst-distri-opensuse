# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select given PATTERNS or PACKAGES
#    You can pass
#    PATTERNS=minimal,base or
#    PATTERNS=all to select all of them
#    PATTERNS=default,web,-x11,-gnome to keep the default but add web and remove x11 and gnome
#    PACKAGES=quota-nfs,-samba,-grub2  packages starting with - will be removed
#    some package will block installation, conflict will be resolved via INSTALLATION_BLOCKED
#
#    For this you need to have needles that provide pattern-base,pattern-minimal...
#    additional to the on-pattern tag
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "y2logsstep";
use strict;
use warnings;
use testapi;

sub accept3rdparty {
    #Third party licenses sometimes appear
    while (check_screen([qw(3rdpartylicense automatic-changes inst-overview)], 15)) {
        last if match_has_tag("automatic-changes");
        last if match_has_tag("inst-overview");
        wait_screen_change { send_key $cmd{acceptlicense} };
    }
}

sub check12qtbug {
    if (check_screen('pattern-too-low', 5)) {
        assert_and_click('pattern-too-low', 'left', 1);
    }
}

sub move_down {
    my $ret = wait_screen_change { send_key 'down' };
    last if (!$ret);    # down didn't change the screen, so exit here
    check12qtbug if check_var('VERSION', '12');
}

sub move_end_and_top {
    wait_screen_change { send_key 'end' };
    wait_screen_change { send_key 'home' };
}

sub gotopatterns {
    my ($self) = @_;
    $self->deal_with_dependency_issues;
    if (check_var('VIDEOMODE', 'text')) {
        wait_still_screen;
        send_key 'alt-c';
        assert_screen 'inst-overview-options';
        send_key 'alt-s';
    }
    else {
        send_key_until_needlematch 'packages-section-selected', 'tab';
        send_key 'ret';
    }
    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        wait_screen_change { send_key 'alt-f' };
        for (1 .. 4) { send_key 'up'; }
        send_key 'ret';
    }
    else {
        send_key 'tab';
    }
    # pressing end and home to have selection more visible, and the scrollbar length is re-caculated
    move_end_and_top;
    assert_screen 'patterns-list-selected';
}

sub gotodetails {
    my ($unblock, $secondrun) = @_;
    my $operation;
    my $packages = $unblock ? get_var('INSTALLATION_BLOCKED') : get_var('PACKAGES');
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-f';
        for (1 .. 4) { send_key 'down'; }
        send_key 'ret';
        assert_screen 'search-list-selected';
    }
    else {
        send_key 'alt-d';    # details button
        assert_screen 'packages-manager-detail';
        assert_and_click 'packages-search-tab';
    }
    for my $p (split(/,/, $packages)) {
        if ($p =~ /^-/) {
            $operation = 'minus';
        }
        else {
            $operation = '+';
        }
        $p =~ s/^-//;        # remove first -
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-p';
            assert_screen 'packages-search-field-selected';
            send_key_until_needlematch 'search-field-empty', 'backspace';
            type_string "$p";
            send_key 'ret';    # search package
        }
        else {
            assert_and_click 'packages-search-field-selected';
            wait_screen_change { send_key 'ctrl-a' };
            wait_screen_change { send_key 'delete' };
            type_string "$p";
            send_key 'alt-s';    # search button
        }
        send_key_until_needlematch "packages-$p-selected", 'down', 60;
        wait_screen_change { send_key "$operation" };
        wait_still_screen 2;
        save_screenshot;
    }
    wait_screen_change { send_key 'alt-a' };    # accept
    sleep 2;                                    # wait_screen_change is too fast

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a';                       # accept
        accept3rdparty;
        assert_screen 'automatic-changes';
        send_key 'alt-o';                       # Continue
    }
    else {
        send_key 'alt-o';
        accept3rdparty;
    }
    if (get_var('INSTALLATION_BLOCKED') && $secondrun) {
        record_info 'low prio bug', 'bsc#1029660';
        assert_screen 'inst-overview-blocked';
        send_key 'alt-i';
        assert_screen 'startinstall-blocked';
        send_key 'alt-o';
        assert_screen 'inst-overview-blocked';
    }
    else {
        assert_screen 'inst-overview';
    }
}

sub select_all_patterns_by_menu {
    # move mouse on patterns and open menu
    mouse_set 100, 400;
    mouse_click 'right';
    wait_still_screen 3;
    # select action on all patterns
    wait_screen_change { send_key 'a'; };
    # confirm install
    wait_screen_change { send_key 'ret'; };
    mouse_hide;
    save_screenshot;
    send_key 'alt-o';
    accept3rdparty;
    assert_screen 'inst-overview';
}

sub switch_selection {
    my (%args)  = @_;
    my $action  = $args{action};
    my $needles = $args{needles};
    wait_screen_change {
        send_key ' ';
        record_info($action, "");
    };
    assert_screen $needles, 8;
}

sub accept_changes {
    send_key 'alt-o';
    accept3rdparty;
    assert_screen 'inst-overview';
}

sub select_specific_patterns_by_iteration {
    my %patterns;    # set of patterns to be processed
                     # fill with variable values
    @patterns{split(/,/, get_var('PATTERNS'))} = ();

    my $counter = 80;
    # delete special 'all' and 'default' keys from the check
    delete $patterns{default};
    delete $patterns{all};
    while (1) {
        die "looping for too long" unless ($counter--);
        my $needs_to_be_selected;
        my $ret = check_screen('on-pattern', 1);
        # this variable will only be updated when the pattern list entry is under the cursor
        # and the pattern is in the PATTERNS variable and there is a needle for that entry
        my $current_pattern = 'UNKNOWN_PATTERN';

        if ($ret) {    # unneedled pattern
            for my $p (keys %patterns) {
                my $sel     = 1;
                my $pattern = $p;    # store pattern untouched
                if ($p =~ /^-/) {
                    # this pattern shall be deselected as indicated by '-' prefix
                    $sel = 0;
                    $p =~ s/^-//;
                }
                if (match_has_tag("pattern-$p")) {
                    $needs_to_be_selected = $sel;
                    $current_pattern      = $p;
                    delete $patterns{$pattern};    # mark this pattern as processed
                    record_info($current_pattern, $needs_to_be_selected);
                }
            }
        }
        $needs_to_be_selected = 1 if get_var('PATTERNS', '') =~ /all/;

        my $selected = check_screen([qw(current-pattern-selected on-category)], 0);
        if ($selected && $selected->{needle}->has_tag('on-category')) {
            move_down;
            next;
        }
        if ($needs_to_be_selected && !$selected) {
            switch_selection(action => 'select', needles => ['current-pattern-selected']);
        }
        if (get_var('PATTERNS', '') =~ /default/ && !(get_var('PATTERNS', '') =~ /$current_pattern/)) {
            $needs_to_be_selected = $selected;
            record_info("keep default", "");
        }
        if (!$needs_to_be_selected && $selected) {
            switch_selection(action => 'unselect', needles => [qw(current-pattern-unselected current-pattern-autoselected)]);
        }

        # exit earlier if default and all patterns were processed
        last if ((get_var('PATTERNS', '') =~ /default/) && !(scalar keys %patterns));

        move_down;
    }
    # check if we have processed all patterns mentioned in the test suite settings
    my @unseen = keys %patterns;
    die "Not all patterns given in the job settings were processed:" . join(", ", @unseen) if @unseen;
}

sub process_patterns {
    if (get_var('PATTERNS')) {
        if (check_var('PATTERNS', 'all') && !check_var('VIDEOMODE', 'text')) {
            select_all_patterns_by_menu;
            return 1;
        }
        select_specific_patterns_by_iteration;
    }
    return 0;
}

sub process_packages {
    my $self      = shift;
    my $secondrun = 0;       # bsc#1029660
    gotodetails;
    $secondrun++;
    $self->gotopatterns;
    gotodetails;
    $secondrun--;
    $self->gotopatterns;
    gotodetails('unblock', $secondrun);
}

sub run {
    my ($self) = @_;
    $self->gotopatterns;
    return if process_patterns;
    return $self->process_packages if get_var('PACKAGES');
    accept_changes;
}

1;
