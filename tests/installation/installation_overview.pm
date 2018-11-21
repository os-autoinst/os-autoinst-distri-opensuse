# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
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
use version_utils 'sle_version_at_least';


sub ensure_ssh_unblocked {
    my $need_ssh = check_var('ARCH', 's390x');    # s390x always needs SSH
    $need_ssh = 1 if check_var('BACKEND', 'ipmi');    # we better be able to login
    $need_ssh = 1 if check_var('BACKEND', 'spvm');    # we better be able to login

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
        #performance ci need diable firewall
        if(get_var('PERF_KERNEL')) {
            send_key_until_needlematch [qw(firewall-enable firewall-disable)], 'tab';
            if (match_has_tag 'firewall-enable') {
               if (get_var('FIREWALL')) {
                   send_key 'alt-c';
                   assert_screen 'inst-overview-options';
                   send_key 'alt-f';
                   assert_screen 'firewall-config';
                   send_key 'alt-e';
                   assert_screen 'firewall-config-dis';
                   send_key 'alt-o';
                   assert_screen 'back_to_installation_settings'
               }
           }
        }
    }
}

sub run {
    my ($self) = shift;
    # overview-generation
    # this is almost impossible to check for real
    assert_screen "installation-settings-overview-loaded", 150;
    $self->deal_with_dependency_issues;
    assert_screen "inst-xen-pattern" if get_var('XEN');
    ensure_ssh_unblocked;
}

1;
