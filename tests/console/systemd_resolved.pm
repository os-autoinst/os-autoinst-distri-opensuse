# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd_resolved
# Summary: Check that the network daemon in use is the expected one
# - setup the nss resolved in /etc/nsswitch.conf
# - test some DNS queries
# - setting up systemd resolved locally, switch /etc/resolv.conf to it
# Maintainer: qe-core <qe-core@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub run {
    select_serial_terminal;

    assert_script_run 'ip a';

    zypper_call 'in systemd-networkd systemd-resolved nss-mdns';
    systemctl 'disable NetworkManager', timeout => 30;
    systemctl 'enable systemd-networkd', timeout => 30;
    systemctl 'enable systemd-resolved', timeout => 30;
    systemctl 'start systemd-resolved', timeout => 30;
    assert_script_run 'rm /etc/resolv.conf';
    assert_script_run 'ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf';
    assert_script_run "sed -i 's/^hosts:    /^hosts:    resolved /' /etc/nsswitch.conf";
    script_run 'cat /etc/nsswitch.conf';
    validate_script_output("resolvectl status", sub { m/Global/ });
    validate_script_output("resolvectl query www.suse.com", sub { m/104.18.32.190/ });
}

1;
