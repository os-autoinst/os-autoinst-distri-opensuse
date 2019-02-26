# Copyright (C) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for network daemon
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    select_console 'root-console';

    assert_script_run 'ip a';

    if (is_opensuse) {
        # check for systemd-networkd
        systemctl 'is-enabled systemd-networkd', expect_false => 1;
        systemctl 'is-active systemd-networkd',  expect_false => 1;
        assert_script_run 'networkctl status';
    }

    my $network_daemon = script_output 'readlink /etc/systemd/system/network.service | sed \'s#.*/\(.*\)\.service#\1#\'';

    record_info $network_daemon, "$network_daemon was detected as the configured network daemon for this system.";

    my $expected = 'NetworkManager';
    my $reason   = 'DESKTOP!=textmode';

    if (is_sle) {
        if (is_server) {
            $expected = 'wicked';
            $reason   = 'SLES';
        }
        elsif (is_jeos) {
            $expected = 'wicked';
            $reason   = 'JeOS';
        }
        else {
            $expected = 'NetworkManager';
            $reason   = 'SLED';
        }
    }
    elsif (check_var('DESKTOP', 'textmode')) {
        $expected = 'wicked';
        $reason   = 'DESKTOP=textmode';
    }

    if ($expected ne $network_daemon) {
        die "Expected '$expected' for $reason but got '$network_daemon'";
    }

    # check if network daemon is installed, enabled and running
    assert_script_run "rpm -q $network_daemon";
    systemctl "is-enabled $network_daemon";
    systemctl "is-active $network_daemon";
    systemctl "status $network_daemon";
    assert_script_run(($network_daemon eq "wicked") ? 'wicked show all' : 'nmcli');
}

1;
