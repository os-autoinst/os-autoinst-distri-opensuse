# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd wireguard-tools iperf iproute2 openssh
# Summary: Connect two machines using wireguard VPN
# Test wireguard with nmcli
# Maintainer: qe-core <qe-core@suse.com>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use registration;
use lockapi;
use mmapi 'wait_for_children';

sub run {
    if (get_var('IS_MM_SERVER')) {
        barrier_create 'SETUP_DONE', 2;
        barrier_create 'WG_NM_READY', 2;
        barrier_create 'WG_NM_ENABLED', 2;
        mutex_create 'barrier_setup_done';
    }

    mutex_wait 'barrier_setup_done';
    select_serial_terminal;
    barrier_wait 'SETUP_DONE';

    # Configure wireguard VPN server and client IP
    my ($vpn_local, $vpn_remote, $remote);
    if (get_var('IS_MM_SERVER')) {
        $remote = '10.0.2.102';
        $vpn_local = '192.168.2.1';
        $vpn_remote = '192.168.2.2';
    } else {
        $remote = '10.0.2.101';
        $vpn_local = '192.168.2.2';
        $vpn_remote = '192.168.2.1';
    }
    zypper_call 'in wireguard-tools';
    ## Test wireguard with NetworkManager
    assert_script_run('cd /etc/wireguard');
    if (get_var('IS_MM_SERVER')) {
        # Prepare new keys
        assert_script_run('wg genkey | tee server | wg pubkey > server.pub');
        assert_script_run('wg genkey | tee client1 | wg pubkey > client1.pub');
        assert_script_run('wg genkey | tee client2 | wg pubkey > client2.pub');
        assert_script_run('ip a && ip r');
        exec_and_insert_password("scp -o StrictHostKeyChecking=no server.pub client* $remote:/etc/wireguard/");
        script_run('nmcli con add type wireguard con-name wg0 ifname wg0 autoconnect no');
        script_run('nmcli con mod wg0 connection.autoconnect no');
        script_run("nmcli con mod wg0 ipv4.method manual ipv4.addresses $vpn_local");
        script_run("nmcli con mod wg0 wireguard.private-key `cat /etc/wireguard/server`");
        script_run("nmcli con mod wg0 +wireguard.peer-routes true +wireguard.listen-port 51820");
        script_run('echo -e "[wireguard-peer.`cat /etc/wireguard/client1.pub`]\nallowed-ips=192.168.2.2\npersistent-keepalive=25\n[wireguard-peer.`cat /etc/wireguard/client2.pub`]\nallowed-ips=192.168.2.3\npersistent-keepalive=25\n" >> /etc/NetworkManager/system-connections/wg0.nmconnection');
        script_run('cat /etc/NetworkManager/system-connections/wg0.nmconnection');
        script_run('nmcli con load /etc/NetworkManager/system-connections/wg0.nmconnection');
        script_run('nmcli con show wg0');
        script_run('nmcli con up wg0');
        script_run('WG_HIDE_KEYS=never wg show wg0');
        script_run('ip address show wg0');
        script_run('echo "Server ready"');
        barrier_wait('WG_NM_READY');
        script_run('echo "Waiting for clients ... "');
        barrier_wait('WG_NM_ENABLED');
        script_retry("ping -c10 $vpn_remote", delay => 3, retry => 10);
    } else {
        script_run('echo "Waiting for server ... "');
        barrier_wait('WG_NM_READY');
        script_run('nmcli con add type wireguard con-name wg2 ifname wg2 autoconnect no');
        script_run('nmcli con mod wg2 connection.autoconnect no');
        script_run("nmcli con mod wg2 ipv4.method manual ipv4.addresses 192.168.2.3");
        script_run("nmcli con mod wg2 wireguard.private-key `cat /etc/wireguard/client2`");
        script_run("nmcli con mod wg2 +wireguard.peer-routes true +wireguard.listen-port 51820");
        script_run('echo -e "[wireguard-peer.`cat /etc/wireguard/server.pub`]\nallowed-ips=192.168.2.1/32\nendpoint=' . "$remote:51820" . '\npersistent-keepalive=25\n" >> /etc/NetworkManager/system-connections/wg2.nmconnection');
        script_run('cat /etc/NetworkManager/system-connections/wg2.nmconnection');
        script_run('nmcli con load /etc/NetworkManager/system-connections/wg2.nmconnection');
        script_run('nmcli con show wg2');
        script_run('nmcli con up wg2');
        script_run('WG_HIDE_KEYS=never wg show wg2');
        script_run('ip address show wg2');
        script_retry("ping -c10 $vpn_remote", delay => 3, retry => 10);
        assert_script_run('nmcli con down wg2');
        # client1 - the server expects client1 to be online
        script_run('nmcli con add type wireguard con-name wg1 ifname wg1 autoconnect no');
        script_run('nmcli con mod wg1 connection.autoconnect no');
        script_run("nmcli con mod wg1 ipv4.method manual ipv4.addresses $vpn_local");
        script_run("nmcli con mod wg1 ipv4.gateway $vpn_remote");
        script_run("nmcli con mod wg1 wireguard.private-key `cat /etc/wireguard/client1`");
        script_run('echo -e "[wireguard-peer.`cat /etc/wireguard/server.pub`]\nallowed-ips=192.168.2.0/24\nendpoint=' . "$remote:51820" . '\npersistent-keepalive=25\n" >> /etc/NetworkManager/system-connections/wg1.nmconnection');
        script_run('cat /etc/NetworkManager/system-connections/wg1.nmconnection');
        script_run('nmcli con load /etc/NetworkManager/system-connections/wg1.nmconnection');
        script_run('nmcli con show wg1');
        script_run('nmcli con up wg1');
        barrier_wait('WG_NM_ENABLED');
        script_retry("ping -c10 $vpn_remote", delay => 3, retry => 10);
    }
    # Finish job
    wait_for_children if (get_var('IS_MM_SERVER'));

}

1;
