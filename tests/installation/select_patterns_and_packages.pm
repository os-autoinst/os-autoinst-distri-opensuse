# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select given PATTERNS or PACKAGES
#    You can pass
#    PATTERNS=minimal,base or
#    PATTERNS=all to select all of them
#    PACKAGES=quota-nfs,-samba,-grub2  packages starting with - will be removed
#    some package will block installation, conflict will be resolved via INSTALLATION_BLOCKED
#
#    For this you need to have needles that provide pattern-base,pattern-minimal...
#    additional to the on-pattern tag
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "y2logsstep";
use strict;
use testapi;

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
    my $self = @_;
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

    if (check_screen('dependancy-issue', 10) && get_var("WORKAROUND_DEPS")) {
        $self->record_dependency_issues;
    }

    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-f';
        for (1 .. 4) { send_key 'up'; }
        send_key 'ret';
        assert_screen 'patterns-list-selected';
    }
    else {
        send_key 'tab';
        send_key ' ';
        assert_screen 'patterns-list-selected';
    }
}

sub package_action {
    my $unblock = @_;
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
            send_key_until_needlematch "packages-$p-selected", 'down', 40;
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
        send_key 'alt-o';                           # OK
    }
    else {
        send_key 'alt-o';
        accept3rdparty;
    }
    if (get_var('INSTALLATION_BLOCKED') && $secondrun) {
        record_soft_failure 'bsc#1029660';
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
    my $self = shift;

    gotopatterns;
    if (get_var('PATTERNS')) {
        my %wanted_patterns;
        for my $p (split(/,/, get_var('PATTERNS'))) {
            $wanted_patterns{$p} = 1;
        }

        my $counter = 70;
        while (1) {
            die "looping for too long" unless ($counter--);
            my $needs_to_be_selected;
            my $ret = check_screen('on-pattern', 1);

            if ($ret) {    # unneedled pattern
                for my $wp (keys %wanted_patterns) {
                    if (match_has_tag("pattern-$wp")) {
                        $needs_to_be_selected = 1;
                    }
                }
            }
            $needs_to_be_selected = 1 if ($wanted_patterns{all});

            my $selected = check_screen([qw(current-pattern-selected on-category)], 0);

            if ($selected && $selected->{needle}->has_tag('on-category')) {
                movedownelseend;
                check12qtbug;
                next;
            }
            if ($needs_to_be_selected && !$selected) {
                wait_screen_change {
                    send_key ' ';
                };
                assert_screen 'current-pattern-selected', 5;
            }

            # stick to the default patterns
            if (get_var('PATTERNS', '') =~ /default/) {
                $needs_to_be_selected = $selected;
            }
            if (!$needs_to_be_selected && $selected) {
                send_key ' ';
                assert_screen [qw(current-pattern-unselected current-pattern-autoselected)], 8;
            }
            movedownelseend;
            check12qtbug;
        }
    }
    package_action;
    $secondrun++;
    gotopatterns;
    package_action;
    $secondrun--;
    gotopatterns;
    package_action('unblock');
}

1;
# vim: set sw=4 et:
