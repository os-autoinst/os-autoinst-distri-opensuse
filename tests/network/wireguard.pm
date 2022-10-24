# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd wireguard-tools iperf iproute2 openssh
# Summary: Connect two machines using wireguard VPN
#  Run iperf3 speed test inside the tunnel for verification
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use version_utils 'is_sle';
use registration;
use lockapi;
use mmapi 'wait_for_children';

sub start_wgquick {
    foreach my $dev (@_) {
        # Start wg-quick with some debug output on failure
        if (script_run("systemctl start wg-quick\@$dev") != 0) {
            script_run("systemctl status wg-quick\@$dev");
            script_run('journalctl -e');
            die "wg-quick failed for $dev";
        }
    }
}

sub run {
    if (get_var('IS_MM_SERVER')) {
        barrier_create 'SETUP_DONE', 2;
        barrier_create 'KEY_TRANSFERED', 2;
        barrier_create 'VPN_ESTABLISHED', 2;
        barrier_create 'IPERF_COMPLETED', 2;
        barrier_create 'WG_QUICK_READY', 2;
        barrier_create 'WG_QUICK_ENABLED', 2;
        mutex_create 'barrier_setup_done';
    }

    mutex_wait 'barrier_setup_done';

    select_serial_terminal;
    barrier_wait 'SETUP_DONE';

    my ($vpn_local, $vpn_remote, $remote);
    if (get_var('IS_MM_SERVER')) {
        $vpn_local = '192.168.2.1';
        $vpn_remote = '192.168.2.2';
        $remote = '10.0.2.102';
    } else {
        $vpn_local = '192.168.2.2';
        $vpn_remote = '192.168.2.1';
        $remote = '10.0.2.101';
    }

    if (is_sle()) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product(get_addon_fullname('we'), undef, undef, "-r " . get_required_var('SCC_REGCODE_WE'), 300, 1);
        # Workaround https://bugzilla.suse.com/show_bug.cgi?id=1181941
        zypper_call '--gpg-auto-import-keys ref';
        add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1);
        # Workaround https://bugzilla.suse.com/show_bug.cgi?id=1182004
        zypper_call '--gpg-auto-import-keys ref';
        zypper_call 'in kernel-default-extra';
        assert_script_run 'modprobe wireguard';
    }

    my $boot_config = '/boot/config-$(uname -r)';
    assert_script_run("grep -i CONFIG_WIREGUARD $boot_config") unless (script_run("stat $boot_config") != 0);
    assert_script_run 'modinfo wireguard';

    zypper_call 'in wireguard-tools iperf';

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

    if (get_var('IS_MM_SERVER')) {
        assert_script_run "iperf3 --bind $vpn_local --server --daemon --port 5001";
        script_retry 'ss -lptn | grep 5001', delay => 3, retry => 3;
        mutex_create 'server_ready';
    } else {
        mutex_unlock 'server_ready';
        script_retry "iperf3 --bind $vpn_local --time 30 --client $vpn_remote --port 5001", timeout => 60, delay => 3, retry => 3;
    }
    barrier_wait('IPERF_COMPLETED');

    assert_script_run 'ip link set down dev wg0';
    assert_script_run 'ip link delete dev wg0';

    ## Test wg-quick
    assert_script_run('set -eo pipefail');
    assert_script_run('cd /etc/wireguard');
    if (get_var('IS_MM_SERVER')) {
        # Prepare new keys
        assert_script_run('wg genkey | tee server | wg pubkey > server.pub');
        assert_script_run('wg genkey | tee client1 | wg pubkey > client1.pub');
        assert_script_run('wg genkey | tee client2 | wg pubkey > client2.pub');
        assert_script_run('ip a && ip r');
        exec_and_insert_password("scp -o StrictHostKeyChecking=no server.pub client* $remote:/etc/wireguard/");
        # Prepare configuration script
        assert_script_run('echo -e "[Interface]\nPrivateKey = `cat /etc/wireguard/server`\nAddress = ' . "$vpn_local\n" . 'ListenPort = 51820\n" > /etc/wireguard/wg0.conf');
        assert_script_run('echo -e "[Peer]\nPublicKey = `cat /etc/wireguard/client1.pub`\nAllowedIPs = 192.168.2.2\nPersistentKeepalive = 25\n" >> /etc/wireguard/wg0.conf');
        assert_script_run('echo -e "[Peer]\nPublicKey = `cat /etc/wireguard/client2.pub`\nAllowedIPs = 192.168.2.3\nPersistentKeepalive = 25\n" >> /etc/wireguard/wg0.conf');
        script_run('cat /etc/wireguard/wg0.conf');
        start_wgquick("wg0");
        script_run('echo "Server ready"');
        barrier_wait('WG_QUICK_READY');
        script_run('echo "Waiting for clients ... "');
        barrier_wait('WG_QUICK_ENABLED');
        script_retry("ping -c10 $vpn_remote", delay => 3, retry => 10);
    } else {
        script_run('echo "Waiting for server ... "');
        barrier_wait('WG_QUICK_READY');
        # client2
        assert_script_run('echo -e "[Interface]\nPrivateKey = `cat /etc/wireguard/client2`\nAddress = 192.168.2.3\n" > /etc/wireguard/wg2.conf');
        assert_script_run('echo -e "[Peer]\nPublicKey = `cat /etc/wireguard/server.pub`\nEndpoint=' . "$remote:51820\n" . '\nAllowedIPs = 192.168.2.0/24" >> /etc/wireguard/wg2.conf');
        script_run('cat /etc/wireguard/wg2.conf');
        start_wgquick("wg2");
        script_retry("ping -c10 $vpn_remote", delay => 3, retry => 10);
        assert_script_run('systemctl stop wg-quick@wg2');
        # client1 - the server expects client1 to be online after WG_QUICK_ENABLED
        assert_script_run('echo -e "[Interface]\nPrivateKey = `cat /etc/wireguard/client1`\nAddress = 192.168.2.2\n" > /etc/wireguard/wg1.conf');
        assert_script_run('echo -e "[Peer]\nPublicKey = `cat /etc/wireguard/server.pub`\nEndpoint=' . "$remote:51820\n" . '\nAllowedIPs = 192.168.2.0/24" >> /etc/wireguard/wg1.conf');
        script_run('cat /etc/wireguard/wg1.conf');
        start_wgquick("wg1");
        barrier_wait('WG_QUICK_ENABLED');
        script_retry("ping -c10 $vpn_remote", delay => 3, retry => 10);
    }
    # Finish job
    wait_for_children if (get_var('IS_MM_SERVER'));

}

1;
