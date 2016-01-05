#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my ($self) = shift;

    # overview-generation
    # this is almost impossible to check for real
    assert_screen "inst-overview", 15;
    if (get_var("XEN")) {
        assert_screen "inst-xen-pattern", 5;
    }

    # preserve it for the video
    wait_idle 10;

    # check for dependency issues, if found, drill down to software selection, take a screenshot, then die
    if (check_screen("inst-overview-dep-warning", 1)) {
        record_soft_failure;
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-c';
            assert_screen 'inst-overview-options', 3;
            send_key 'alt-s';
        }
        else {
            send_key_until_needlematch 'packages-section-selected', 'tab';
            send_key 'ret';
        }

        assert_screen 'dependancy-issue';    #make sure the dependancy issue is actually showing

        if (get_var("WORKAROUND_DEPS")) {
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
            send_key 'alt-a',                           3;
            send_key 'alt-o',                           3;
            assert_screen "inst-overview-after-depfix", 15;    # Make sure you're back on the inst-overview before doing anything else
        }
        else {
            save_screenshot;
            die 'Dependancy Problems';
        }
    }

    if (check_var('BACKEND', 's390x')) {                       # s390x always needs SSH
        if (!check_screen('ssh-open', 5)) {
            send_key_until_needlematch 'ssh-blocked-selected', 'tab';
            send_key 'ret';
            assert_screen 'ssh-open';
        }
    }

    # Save configuration as an autoyast profile
    # SLE's default is 'enabled' - so no action needed there.
    if (!check_var('DISTRI', 'sle')) {
        if (!check_screen('ay-save-profile', 5)) {
            send_key_until_needlematch 'ay-writeit-selected', 'tab';
            send_key 'ret';
        }
    }
}

1;
# vim: set sw=4 et:
