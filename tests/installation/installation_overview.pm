# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

    # check for dependency issues, if found, drill down to software selection, take a screenshot, then die
    if (check_screen("inst-overview-dep-warning", 1)) {
        record_soft_failure;
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

    if (check_var('ARCH', 's390x')) {                   # s390x always needs SSH
        if (!check_screen('ssh-open', 5)) {
            send_key_until_needlematch 'ssh-blocked-selected', 'tab';
            send_key 'ret';
            assert_screen 'ssh-open';
        }
    
        # Workaround for bsc#963008
        record_soft_failure;
        if (!check_screen('firewall-disabled', 5)) {
            send_key_until_needlematch 'firewall-enabled-selected', 'tab';
            send_key 'ret';
            assert_screen 'firewall-disabled';
        }
    }
}

1;
# vim: set sw=4 et:
