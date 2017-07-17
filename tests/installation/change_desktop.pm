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

use base "installsummarystep";
use strict;
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

    if (check_screen('dependancy-issue', 10) && get_var("WORKAROUND_DEPS")) {
        while (check_screen 'dependancy-issue', 5) {
            if (check_var('VIDEOMODE', 'text')) {
                wait_screen_change { send_key 'alt-s'; };
            }
            else {
                wait_screen_change { send_key 'alt-1'; };
            }
            wait_screen_change { send_key 'spc'; };
            send_key 'alt-o';
        }
    }

    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        wait_screen_change { send_key 'alt-f'; };
        for (1 .. 4) {
            wait_screen_change { send_key 'up'; };
        }
        send_key 'ret';
        send_key_until_needlematch 'patterns-list-selected', 'tab', 10;
    }
    else {
        send_key_until_needlematch 'patterns-list-selected', 'tab', 10;
    }

    if (get_var('SYSTEM_ROLE')) {
        assert_screen "desktop-unselected";
    }
    else {
        if (!check_var('DESKTOP', 'gnome')) {
            send_key_until_needlematch 'gnome-selected', 'down', 10;
            send_key ' ';
        }
        if (check_var('DESKTOP', 'kde')) {
            send_key_until_needlematch 'kde-unselected', 'down', 10;
            send_key ' ';
        }
        if (check_var('DESKTOP', 'textmode')) {
            send_key_until_needlematch 'x11-selected', 'down', 10;
            send_key ' ';
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
# vim: set sw=4 et:
