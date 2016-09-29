# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: restructure opensuse install test code
#    this splits monolitic yast1b and yast2 modules
#    into finer grained single-task modules
# G-Maintainer: Bernhard M. Wiedemann <bernhard+osautoinst lsmod de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my ($self) = shift;

    # overview-generation
    # this is almost impossible to check for real
    assert_screen "inst-overview";
    if (get_var("XEN")) {
        assert_screen "inst-xen-pattern";
    }

    # preserve it for the video
    wait_idle 10;

    # Check autoyast has been removed in SP2 (fate#317970)
    if (get_var("SP2ORLATER") && !check_var("INSTALL_TO_OTHERS", 1)) {
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-l';
            send_key 'ret';
            send_key 'tab';
        }
        else {
            send_key_until_needlematch 'packages-section-selected', 'tab';
        }
        send_key 'end';
        assert_screen 'autoyast_removed';
    }

    # check for dependency issues, if found, drill down to software selection, take a screenshot, then die
    if (check_screen("inst-overview-dep-warning", 1)) {
        record_soft_failure 'dependency warning';
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-c';
            assert_screen 'inst-overview-options';
            send_key 'alt-s';
        }
        else {
            send_key_until_needlematch 'packages-section-selected', 'tab';
            send_key 'ret';
        }

        assert_screen 'dependancy-issue';    #make sure the dependancy issue is actually showing

        if (get_var("WORKAROUND_DEPS")) {
            $self->record_dependency_issues;
            wait_screen_change {
                send_key 'alt-a';
            };
            send_key 'alt-o';
            assert_screen "inst-overview-after-depfix";    # Make sure you're back on the inst-overview before doing anything else
        }
        else {
            save_screenshot;
            die 'Dependancy Problems';
        }
    }

    if (check_var('ARCH', 's390x') && !get_var('UPGRADE')) {    # s390x always needs SSH

        send_key_until_needlematch [qw/ssh-blocked ssh-open/], 'tab';
        if (match_has_tag 'ssh-blocked') {
            if (check_var('VIDEOMODE', 'text')) {
                send_key 'alt-c';
                assert_screen 'inst-overview-options';
                send_key 'alt-f';
                assert_screen 'firewall-config';
                send_key 'alt-p';
                send_key 'alt-o';
            }
            else {
                send_key_until_needlematch 'ssh-blocked-selected', 'tab';
                send_key 'ret';
                send_key_until_needlematch 'ssh-open', 'tab';
            }
        }
    }
}

1;
# vim: set sw=4 et:
