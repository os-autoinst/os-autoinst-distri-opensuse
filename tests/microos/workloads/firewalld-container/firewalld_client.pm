# SUSE"s openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman firewalld-container
# Summary: install and verify firewalld container.
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use warnings;
use strict;
use testapi;
use lockapi;
use utils qw(set_hostname script_retry);
use mm_network 'setup_static_mm_network';

# MM network check: try to ping the gateway, and the server
sub ensure_server_reachable {
    assert_script_run('ping -c 1 10.0.2.2');
    assert_script_run('ping -c 1 10.0.2.101');
}

sub run {
    my ($self) = @_;
    select_console 'root-console';
    set_hostname(get_var('HOSTNAME') // 'client');
    # 101 = server, 102 = client
    setup_static_mm_network('10.0.2.102/24');
    mutex_wait 'barrier_setup_done';
    barrier_wait 'FIREWALLD_CLIENT_READY';
    barrier_wait 'FIREWALLD_SERVER_READY';
    ensure_server_reachable();
    barrier_wait 'FIREWALLD_SERVER_PORT_OPEN';
    # ensure the port is open on the server
    my $network_probe = 'curl http://10.0.2.101:8080/';
    script_retry($network_probe, retry => 3, delay => 30);
    # wait for port being closed by firewall
    barrier_wait 'FIREWALLD_SERVER_PORT_CLOSED';
    # the next command should fail because port 8080 is closed
    die if (script_run($network_probe) == 0);
    barrier_wait 'FIREWALLD_TEST_FINISHED';
}

1;

