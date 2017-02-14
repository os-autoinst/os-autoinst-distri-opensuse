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
use base "y2logsstep";
use utils;
use testapi;

sub run() {
    my $role = get_var('SYSTEM_ROLE', 'admin');

    # Select proper role
    send_key 'alt-s';
    send_key_until_needlematch "system-role-$role", 'down', 2;

    # Set dashboard url for worker
    if ($role eq 'worker') {
        # Try with empty controller node
        send_key 'alt-i';
        assert_screen 'inst-userpasswdtoosimple';
        send_key 'alt-y';
        assert_screen 'controller-node-invalid';
        send_key 'alt-o';

        # Fill controller node information
        send_key 'alt-c';
        type_string 'dashboard-url';
        assert_screen 'dashboard-url';
    }
}

1;
# vim: set sw=4 et:
