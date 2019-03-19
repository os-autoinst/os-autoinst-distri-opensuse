# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Kubic kubeadm role configuration
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use caasp;
use caasp_controller '$admin_fqdn';

sub run {
    assert_screen 'caasp-role-config';

    my $role = get_var('SYSTEM_ROLE', 'admin');
    if ($role eq 'worker') {
        # Try with empty controller node
        send_alt 'next';
        assert_screen 'controller-node-invalid';
        send_alt 'ok';

        # Fill controller node information
        send_key 'alt-a';
        type_string(get_var('STACK_ROLE') ? $admin_fqdn : 'dashboard-url');
        assert_screen 'dashboard-url';
    }

    # Both admin / worker have ntp now
    if (check_screen 'ntp-servers-empty') {
        # Try without ntp servers
        send_alt 'next';
        assert_screen 'ntp-servers-missing';
        send_alt 'no';
    }
    send_alt 'ntpserver';
    type_string 'ns.openqa.test';
    # 0.opensuse.pool.ntp.org

    sleep 1;
    save_screenshot;
    send_alt 'next';
}

1;
