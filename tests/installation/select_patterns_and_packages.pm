# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
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
use testapi;
use version_utils 'is_sle';

my $secondrun = 0;    # bsc#1029660

sub accept3rdparty {
    #Third party licenses sometimes appear
    while (check_screen([qw(3rdpartylicense automatic-changes inst-overview)], 15)) {
        last if match_has_tag("automatic-changes");
        last if match_has_tag("inst-overview");
        wait_screen_change {
            send_key $cmd{acceptlicense};
        };
    }
}

sub movedownelseend {
    my $ret = wait_screen_change {
        send_key 'down';
    };
    # down didn't change the screen, so exit here
    last if (!$ret);
}

sub check12qtbug {
    if (check_var('VERSION', '12')) {
        if (check_screen('pattern-too-low', 5)) {
            assert_and_click('pattern-too-low', 'left', 1);
        }
    }
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
    # pressing up and down to have selection more visible
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'up' };
    assert_screen 'patterns-list-selected';
}

sub package_action {
    my ($self, $unblock) = @_;
    my $operation;
    my $packages = $unblock ? get_var('INSTALLATION_BLOCKED') : get_var('PACKAGES');
    if (get_var('PACKAGES')) {
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
    }

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a';                           # accept
        accept3rdparty;
        assert_screen 'automatic-changes';
        send_key 'alt-o';                           # Continue
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

sub run {
    my ($self) = @_;
    my $dep_issue;
    $self->gotopatterns;
    # select all patterns via menu and end in graphical mode
    if (check_var('PATTERNS', 'all') && !check_var('VIDEOMODE', 'text')) {
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
        return 1;
    }
    if (get_var('PATTERNS')) {
        my %patterns;              # set of patterns to be processed
        my %processed_patterns;    # set of the processed patterns

        # fill with variable values
        @patterns{split(/,/, get_var('PATTERNS'))} = ();

        my $counter = 80;
        while (1) {
            die "looping for too long" unless ($counter--);
            my $needs_to_be_selected;
            my $ret = check_screen('on-pattern', 1);
            # this variable will only be updated when the pattern list entry is under the cursor
            # and the pattern is in the PATTERNS variable and there is a needle for that entry
            my $current_pattern = 'UNKNOWN_PATTERN';

            if ($ret) {    # unneedled pattern
                for my $p (keys %patterns) {
                    my $sel = 1;
                    if ($p =~ /^-/) {
                        # this pattern shall be deselected as indicated by '-' prefix
                        $sel = 0;
                        $p =~ s/^-//;
                    }
                    if (match_has_tag("pattern-$p")) {
                        $needs_to_be_selected = $sel;
                        $current_pattern      = $p;
                        # add pattern to the set of detected patterns
                        $processed_patterns{$p} = undef;
                        record_info($current_pattern, $needs_to_be_selected);
                    }
                }
            }
            $needs_to_be_selected = 1 if ($patterns{all});

            my $selected = check_screen([qw(current-pattern-selected on-category)], 0);

            if ($selected && $selected->{needle}->has_tag('on-category')) {
                movedownelseend;
                check12qtbug;
                next;
            }
            if ($needs_to_be_selected && !$selected) {
                wait_screen_change {
                    send_key ' ';
                    record_info("select", "");
                };
                assert_screen 'current-pattern-selected', 5;
            }
            # stick to the default patterns. Check if at least 1 dep. issue was displayed
            $dep_issue = $self->workaround_dependency_issues || $dep_issue;

            if (get_var('PATTERNS', '') =~ /default/ && !(get_var('PATTERNS', '') =~ /$current_pattern/)) {
                $needs_to_be_selected = $selected;
                record_info("keep default", "");
            }
            if (!$needs_to_be_selected && $selected) {
                send_key ' ';
                record_info("unselect", "");
                assert_screen [qw(current-pattern-unselected current-pattern-autoselected)], 8;
            }
            movedownelseend;
            check12qtbug;
        }
        # check if we have processed all patterns mentioned in the test suite settings
        # delete special 'all' and 'default' keys from the check
        delete $patterns{default};
        delete $patterns{all};
        my @unseen;
        foreach my $k (keys %patterns) {
            push @unseen, $k if (not exists $processed_patterns{$k});
        }
        die "Not all patterns given in the job settings were processed:" . join(", ", @unseen) if @unseen;
    }

    $self->package_action;
    unless (is_sle('15+') && check_var('PATTERNS', 'all') && $dep_issue) {
        $secondrun++;
        $self->gotopatterns;
        $self->package_action;
        $secondrun--;
        $self->gotopatterns;
        $self->package_action('unblock');
    }
}

1;
