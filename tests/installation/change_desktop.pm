# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package change_desktop;
use base "y2logsstep";
use strict;
use testapi;

sub accept3rdparty {
    my ($self) = @_;
    #Third party licenses sometimes appear
    while (check_screen([qw/3rdpartylicense automatic-changes inst-overview/], 15)) {
        last if match_has_tag("automatic-changes");
        last if match_has_tag("inst-overview");
        send_key $cmd{acceptlicense}, 1;
    }
}

sub change_desktop() {
    my ($self) = @_;
    # ncurses offers a faster way
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';
        assert_screen 'inst-overview-options';
        send_key 'alt-s';
    }
    else {
        send_key_until_needlematch 'packages-section-selected', 'tab', 10;
        send_key 'ret';
    }

    if (check_screen('dependancy-issue', 10) && get_var("WORKAROUND_DEPS")) {
        while (check_screen 'dependancy-issue', 5) {
            if (check_var('VIDEOMODE', 'text')) {
                send_key 'alt-s', 3;
            }
            else {
                send_key 'alt-1', 3;
            }
            send_key 'spc',   3;
            send_key 'alt-o', 3;
        }
    }

    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-f';
        for (1 .. 4) { send_key 'up'; }
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
            wait_screen_change { send_key ' '; };
        }
        if (check_var('DESKTOP', 'kde')) {
            send_key_until_needlematch 'kde-unselected', 'down', 10;
            wait_screen_change { send_key ' '; };
        }
        if (check_var('DESKTOP', 'textmode')) {
            send_key_until_needlematch 'x11-selected', 'down', 10;
            wait_screen_change { send_key ' '; };
        }
        assert_screen "desktop-selected";
    }

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a';    # accept
        accept3rdparty;
        assert_screen 'automatic-changes';
        send_key 'alt-o';    # OK
    }
    else {
        send_key 'alt-o';    # OK
        accept3rdparty;
    }
    assert_screen 'inst-overview';

}

sub run {
    my $self = shift;

    $self->change_desktop();
}

1;
# vim: set sw=4 et:
