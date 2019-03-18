# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
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
use version_utils 'is_caasp';
use Utils::Backends 'is_remote_backend';


sub ensure_ssh_unblocked {
    if (!get_var('UPGRADE') && is_remote_backend) {

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
        #performance ci need disable firewall
        if (get_var('DISABLE_FIREWALL')) {
            send_key_until_needlematch [qw(firewall-enable firewall-disable)], 'tab';
            if (match_has_tag 'firewall-enable') {
                send_key 'alt-c';
                assert_screen 'inst-overview-options';
                send_key 'alt-f';
                assert_screen 'firewall-config';
                send_key 'alt-e';
                assert_screen 'firewall-config-dis';
                send_key 'alt-o';
                assert_screen 'back_to_installation_settings';
            }
        }
    }
}

sub run {
    my ($self) = shift;
    # overview-generation
    # this is almost impossible to check for real
    if (is_caasp && check_var('HDDSIZEGB', '10')) {
        # boo#1099762
        assert_screen('installation-settings-overview-loaded-impossible-proposal');
    }
    else {
        # Refer to: https://progress.opensuse.org/issues/47369
        assert_screen "installation-settings-overview-loaded", 250;
        $self->deal_with_dependency_issues;
        assert_screen "inst-xen-pattern" if get_var('XEN');
        ensure_ssh_unblocked;
    }
}

1;
