# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

package change_desktop;
# Summary: [OOP]Change desktop
# Maintainer: Jozef Pupava <jpupava@suse.com>

use y2_logs_helper qw(workaround_dependency_issues workaround_dependency_issues break_dependency);
use base qw(y2_installbase installsummarystep);
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

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

    if (check_screen('dependency-issue', 5) && check_var("WORKAROUND_DEPS", '1')) {
        $self->workaround_dependency_issues;
    }
    if (check_screen('dependency-issue', 0) && check_var("BREAK_DEPS", '1')) {
        $self->break_dependency;
    }

    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        wait_screen_change { send_key 'alt-f'; };
        for (1 .. 4) {
            wait_screen_change { send_key 'up'; };
        }
        wait_screen_change { send_key 'ret'; };
    }

    send_key_until_needlematch 'patterns-list-selected', 'tab', 10, 2;

    if (is_sle('<=12-SP1') && get_var("REGRESSION", '') =~ /xen|kvm|qemu/) {
        assert_and_click 'gnome_logo';
        send_key 'spc';

        assert_and_click 'xorg_logo';
        send_key 'spc';

        if (get_var("REGRESSION", '') =~ /kvm|qemu/) {
            assert_and_click 'kvm_logo';
            send_key 'spc';
        } elsif (check_var("REGRESSION", "xen")) {
            assert_and_click 'xen_logo';
            send_key 'spc';
        }

        assert_and_click 'apparmor_logo';
    }

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
