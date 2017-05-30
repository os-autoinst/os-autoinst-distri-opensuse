# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check installation overview before and after any pattern change
# Maintainer: Richard Brown <RBrownCCB@opensuse.org>

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

    $self->check_and_record_dependency_problems;

    my $need_ssh = check_var('ARCH', 's390x');    # s390x always needs SSH
    $need_ssh = 1 if check_var('BACKEND', 'ipmi');    # we better be able to login

    if (!get_var('UPGRADE') && $need_ssh) {

        send_key_until_needlematch [qw(ssh-blocked ssh-open)], 'tab';
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
                send_key_until_needlematch 'ssh-blocked-selected', 'tab', 25;
                send_key 'ret';
                send_key_until_needlematch 'ssh-open', 'tab';
            }
        }
    }

    if (check_screen('inst-overview-bootloader-warning', 0)) {
        record_soft_failure 'bsc#1024409';
        send_key 'alt-i';    #install
        assert_screen 'inst-overview-error-found';
    }
}

1;
# vim: set sw=4 et:
