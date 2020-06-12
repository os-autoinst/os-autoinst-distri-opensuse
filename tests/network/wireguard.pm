# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Connect two machines using wireguard VPN
#  Run iperf3 speed test inside the tunnel for verification
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;
use mmapi 'wait_for_children';

sub run {
    my $self = shift;

    $self->select_serial_terminal;
    barrier_wait 'SETUP_DONE';

    my ($vpn_local, $vpn_remote, $remote);
    if (get_var('IS_MM_SERVER')) {
        $vpn_local  = '192.168.2.1';
        $vpn_remote = '192.168.2.2';
        $remote     = '10.0.2.102';
    } else {
        $vpn_local  = '192.168.2.2';
        $vpn_remote = '192.168.2.1';
        $remote     = '10.0.2.101';
    }

    assert_script_run 'grep -i CONFIG_WIREGUARD /boot/config-$(uname -r)';
    assert_script_run 'modinfo wireguard';

    zypper_call 'in wireguard-tools';

    assert_script_run 'which wg';
    assert_script_run 'umask 077';
    assert_script_run 'wg genkey > ./private';
    assert_script_run 'test -f ./private';
    assert_script_run 'wg pubkey < ./private | tee ./public';
    exec_and_insert_password("scp -o StrictHostKeyChecking=no ./public root\@$remote:'~/remote'");
    barrier_wait 'KEY_TRANSFERED';
    assert_script_run 'test -f ./remote';

    assert_script_run 'ip link add dev wg0 type wireguard';
    assert_script_run "ip address add dev wg0 $vpn_local/24";
    assert_script_run "wg set wg0 listen-port 51820 private-key ./private";
    assert_script_run "wg set wg0 peer \$(cat ./remote) allowed-ips $vpn_remote/32 endpoint $remote:51820";
    assert_script_run 'ip link set up dev wg0';

    assert_script_run 'ip a s wg0';
    assert_script_run 'wg';

    barrier_wait 'VPN_ESTABLISHED';
    assert_script_run "ping -c10 $vpn_remote";

    zypper_call 'in iperf';

    if (get_var('IS_MM_SERVER')) {
        assert_script_run "iperf3 --bind $vpn_local --server --daemon --port 5001";
        script_retry 'ss -lptn | grep 5001', delay => 3, retry => 3;
        mutex_create 'server_ready';
        wait_for_children;
    } else {
        mutex_unlock 'server_ready';
        script_retry "iperf3 --bind $vpn_local --time 30 --client $vpn_remote --port 5001", timeout => 60, delay => 3, retry => 3;
    }

    assert_script_run 'ip link set down dev wg0';
}

1;
