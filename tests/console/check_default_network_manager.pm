# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd-network
# Summary: Check that the network daemon in use is the expected one
# - check which network daemon is in use
# - based on the system (SLE, JeOS, SLED, openSUSE), check that
#   the running daemon is the expected one (wicked, wicked, NetworkManager, NetworkManager)
# - check if network daemon is installed, enabled and running
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    assert_script_run 'ip a';

    if (is_opensuse) {
        zypper_call 'in systemd-network';
        systemctl 'is-enabled systemd-networkd', expect_false => 1;
        systemctl 'is-active systemd-networkd', expect_false => 1;
        assert_script_run 'networkctl status';
    }

    my $network_daemon = script_output 'readlink /etc/systemd/system/network.service | sed \'s#.*/\(.*\)\.service#\1#\'';

    record_info $network_daemon, "$network_daemon was detected as the configured network daemon for this system.";

    my $expected = 'NetworkManager';
    my $unexpected = 'wicked';
    my $reason = 'networking';

    if (is_jeos && (is_sle || is_leap)) {
        $expected = 'wicked';
        $unexpected = 'NetworkManager';
        $reason = 'JeOS';
    }
    elsif (is_sle) {
        if (is_server) {
            $expected = 'wicked';
            $unexpected = 'NetworkManager';
            $reason = 'SLES';
        }
        else {
            $reason = 'SLED';
        }
    }
    elsif (is_leap && check_var('DESKTOP', 'textmode')) {
        $expected = 'wicked';
        $unexpected = 'NetworkManager';
        $reason = 'DESKTOP=textmode';
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

    systemctl("is-enabled $unexpected", expect_false => 1);
    systemctl("is-active $unexpected", expect_false => 1);
}

1;
