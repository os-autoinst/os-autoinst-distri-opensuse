# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup system role
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use caasp;
use testapi;
use caasp_controller '$admin_fqdn';

sub run {
    my $role = get_var('SYSTEM_ROLE', 'admin');

    # Select proper role
    send_alt 'role';
    send_key_until_needlematch "system-role-$role", 'down', 2;
    send_key 'ret' if (check_var('VIDEOMODE', 'text'));

    if ($role eq 'admin') {
        # Try without ntp servers
        send_alt 'install';
        handle_simple_pw;
        assert_screen 'ntp-servers-missing';
        send_key 'alt-n';

        send_alt 'ntpserver';
        type_string 'ns.openqa.test';
        save_screenshot;
    }
    elsif ($role eq 'worker') {
        # Try with empty controller node
        send_alt 'install';
        handle_simple_pw;
        assert_screen 'controller-node-invalid';
        send_key 'alt-o';

        # Fill controller node information
        send_key 'alt-d';
        type_string(get_var('STACK_ROLE') ? $admin_fqdn : 'dashboard-url');
        assert_screen 'dashboard-url';
    }
}

1;
