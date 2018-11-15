# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test OpenVPN on two machines - this one is server.
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use lockapi;
use y2x11test;
use mm_network;
use mmapi 'wait_for_children';
use utils qw(systemctl zypper_call exec_and_insert_password);
use strict;

sub run {
    barrier_create('OPENVPN_STATIC_START',    2);
    barrier_create('OPENVPN_STATIC_STARTED',  2);
    barrier_create('OPENVPN_STATIC_FINISHED', 2);
    barrier_create('OPENVPN_CA_START',        2);
    barrier_create('OPENVPN_CA_STARTED',      2);
    barrier_create('OPENVPN_CA_FINISHED',     2);
    select_console "root-console";

    my $qa_head_repo = get_var('QA_HEAD_REPO', '');
    zypper_call("ar -Gf '$qa_head_repo'/ qa-ibs");

    # Install openvpn, generate static key
    zypper_call('in openvpn easy-rsa');
    assert_script_run('cd /etc/openvpn');
    assert_script_run('openvpn --genkey --secret static.key');
    mutex_create 'OPENVPN_STATIC_KEY';

    # Write the server config
    assert_script_run(qq(echo "dev tun
ifconfig 10.8.0.1 10.8.0.2
secret /etc/openvpn/static.key" > static.conf));

    # Start the server
    systemctl('start openvpn@static');
    systemctl('status openvpn@static -l');
    barrier_wait 'OPENVPN_STATIC_START';

    # Test the connection when also the client is ready
    barrier_wait 'OPENVPN_STATIC_STARTED';
    assert_script_run("ping -c5 -W1 -I tun0 10.8.0.2");

    # Stop the server when also client is done
    barrier_wait 'OPENVPN_STATIC_FINISHED';
    systemctl('stop openvpn@static');

    # Generate certificates
    assert_script_run("easyrsa init-pki");
    assert_script_run("easyrsa gen-dh",                              240);
    assert_script_run("yes '' | easyrsa build-ca nopass",            120);
    assert_script_run("yes '' | easyrsa gen-req server nopass",      120);
    assert_script_run("echo 'yes' | easyrsa sign-req server server", 120);
    assert_script_run("yes '' | easyrsa gen-req client nopass",      120);
    assert_script_run("echo 'yes' | easyrsa sign-req client client", 120);
    mutex_create 'OPENVPN_CA_KEYS';

    # Write the server config
    assert_script_run(qq(echo "dev tap
mode server
tls-server

cert pki/issued/server.crt
key pki/private/server.key
ca pki/ca.crt
dh pki/dh.pem

ifconfig 10.8.0.1 255.255.255.0
client-config-dir ccd" > ca.conf));

    # Create the client config directory and the file for client
    assert_script_run("mkdir ccd");
    assert_script_run(qq(echo "ifconfig-push 10.8.0.2 255.255.255.0" > ccd/client));

    # Start the server
    systemctl('start openvpn@ca');
    systemctl('status openvpn@ca -l');
    barrier_wait 'OPENVPN_CA_START';

    # Test the connection when also the client is ready
    barrier_wait 'OPENVPN_CA_STARTED';
    assert_script_run("ping -c5 -W1 -I tap0 10.8.0.2");

    # Stop the server when also client is done
    barrier_wait 'OPENVPN_CA_FINISHED';
    systemctl('stop openvpn@ca');
}

1;
