# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for support server network
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use serial_terminal 'select_virtio_console';

sub run {
    select_virtio_console();

    # Check if network is available
    for (1 .. 5) {
        eval {
            # Check support server by ping
            assert_script_run "ping -c 5 -w 10 10.0.2.1";
        };
        last unless ($@);
        record_info 'waiting for network', 'Network is not configured by DHCP yet.';
        sleep 5;
    }
    die "Network is not available." if $@;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
