# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup and test point-to-point VPN using static key with OpenVPN
# Maintainer: Dehai Kong <dhkong@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;
use lockapi;
use mmapi;
use mm_network;
use mm_tests;

sub run {

    my $password = $testapi::password;
    select_console "root-console";

    # Set up openvpn client's IP address
    configure_static_network('10.0.2.10/24');

    # Stop firewall
    assert_script_run("SuSEfirewall2 stop");

    mutex_lock('openvpn');
    mutex_unlock('openvpn');

    # Install openvpn and get static key from openvpn server
    zypper_call("in openvpn");
    assert_script_run("mkdir -p /etc/openvpn/keys");
    script_run("scp root\@10.0.2.1:/etc/openvpn/keys/openvpn.key /etc/openvpn/keys/ | tee /dev/$serialdev", 0);
    wait_still_screen 1;
    type_string("yes\n");
    wait_still_screen 1;
    type_string("$password\n");
    assert_script_run("ls /etc/openvpn/keys/openvpn.key");

    # Setup VPN client
    my $client_conf = <<EOF;
remote 10.0.2.1
dev tun
ifconfig 10.8.0.2 10.8.0.1
secret /etc/openvpn/keys/openvpn.key
cipher AES-256-CBC
EOF
    assert_script_run("echo \"$client_conf\" >> /etc/openvpn/client.conf");
    assert_script_run("systemctl start openvpn\@client.service");
    # Test the encrypted tunnel,Ping server from client
    assert_script_run("ping -c 4 10.8.0.1");
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
