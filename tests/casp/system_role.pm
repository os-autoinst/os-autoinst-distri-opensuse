# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
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
    assert_screen_with_soft_timeout('system-role-admin', timeout => 500, soft_timeout => 30, bugref => 'bsc#1015794');

    my $role = get_var("SYSTEM_ROLE");
    if ($role) {
        if ($role eq 'worker') {
            send_key 'alt-w';
            assert_screen "system-role-$role";

            send_key $cmd{next};
            assert_screen 'worker-registration';

            send_key 'alt-d';
            type_string 'dashboard-ip';
        }
        elsif ($role eq 'plain') {
            send_key 'alt-p';
            assert_screen "system-role-$role";
        }
        else {
            die "Unknown role: $role";
        }
    }

    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
