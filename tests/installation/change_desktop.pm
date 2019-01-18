# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package change_desktop;
# Summary: [OOP]Change desktop
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "y2logsstep";
use base "installsummarystep";
use strict;
use warnings;
use testapi;

sub change_desktop {
    my ($self) = @_;
    # ncurses offers a faster way
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';
        assert_screen 'inst-overview-options';
        wait_screen_change { send_key 'alt-s'; };
    }
    else {
        send_key_until_needlematch 'packages-section-selected', 'tab', 10;
        wait_screen_change { send_key 'ret'; };
    }

    if (check_screen('dependency-issue', 5) && get_var("WORKAROUND_DEPS")) {
        $self->workaround_dependency_issues;
    }
    if (check_screen('dependency-issue', 0) && get_var("BREAK_DEPS")) {
        $self->break_dependency;
    }

    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        wait_screen_change { send_key 'alt-f'; };
        for (1 .. 4) {
            wait_screen_change { send_key 'up'; };
        }
        send_key 'ret';
    }
    send_key_until_needlematch 'patterns-list-selected', 'tab', 10, 2;

    if (get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default')) {
        assert_screen "desktop-unselected";
    }
    else {
        if (!check_var('DESKTOP', 'gnome')) {
            send_key_until_needlematch 'gnome-selected', 'down';
            send_key ' ';
        }
        if (check_var('DESKTOP', 'kde')) {
            send_key_until_needlematch 'kde-unselected', 'down';
            send_key ' ';
        }
        if (check_var('DESKTOP', 'textmode')) {
            send_key_until_needlematch [qw(x11-selected x11-unselected)], 'down';
            send_key ' ' if match_has_tag('x11-selected');
        }
        assert_screen "desktop-selected";
    }
    $self->accept_changes_with_3rd_party_repos;
}

sub run {
    my $self = shift;

    $self->change_desktop();
}

1;
