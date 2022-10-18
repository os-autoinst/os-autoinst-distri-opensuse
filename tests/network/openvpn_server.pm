# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openvpn easy-rsa iputils
# Summary: Test OpenVPN on two machines - this one is the server.
#  * Shared key is generated, server configured and started
#  * After client connects, both sides perform ping, then disconnect
#  * Easy-RSA CA infrastructure is generated, server configured and started
#  * After client connects, both sides perform ping, then disconnect
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use y2_module_guitest;
use mm_network;
use mmapi 'wait_for_children';
use utils qw(systemctl zypper_call exec_and_insert_password script_retry);
use version_utils 'is_opensuse';
use repo_tools 'add_qa_head_repo';
use strict;
use warnings;

sub run {
    my $self = shift;
    barrier_create 'SETUP_DONE', 2;
    barrier_create('OPENVPN_STATIC_STARTED', 2);
    barrier_create('OPENVPN_STATIC_FINISHED', 2);
    barrier_create('OPENVPN_CA_STARTED', 2);
    barrier_create('OPENVPN_CA_FINISHED', 2);
    mutex_create 'barrier_setup_done';
    barrier_wait 'SETUP_DONE';
    select_serial_terminal;

    # Install openvpn, generate static key
    add_qa_head_repo unless is_opensuse();
    zypper_call('in openvpn easy-rsa');
    zypper_call("install openssl") if (script_run("which openssl") != 0);
    assert_script_run('cd /etc/openvpn');
    assert_script_run('openvpn --genkey --secret static.key');
    mutex_create 'OPENVPN_STATIC_KEY';

    # Download the server config
    assert_script_run("curl -o static.conf " . data_url("openvpn/static_server.conf"));

    # Start the server
    systemctl('start openvpn@static');
    systemctl('status openvpn@static -l');

    # Make sure the tunnel has been established
    script_retry('journalctl --no-pager -u openvpn@static | grep "Initialization Sequence Completed"', delay => 15, retry => 12);

    # Test that the interface is present
    assert_script_run("ip a s tun0");
    assert_script_run('ip a s tun0 | grep "10\.8\.0\.1"');

    # Test the connection when also the client is ready
    barrier_wait 'OPENVPN_STATIC_STARTED';
    assert_script_run("ping -c5 -W1 -I tun0 10.8.0.2");

    # Stop the server when also client is done
    barrier_wait 'OPENVPN_STATIC_FINISHED';
    systemctl('stop openvpn@static');

    # Generate certificates
    assert_script_run("easyrsa init-pki");
    assert_script_run("easyrsa gen-dh", 600);
    assert_script_run("yes '' | easyrsa build-ca nopass", 120);
    assert_script_run("yes '' | easyrsa gen-req server nopass", 120);
    assert_script_run("echo 'yes' | easyrsa sign-req server server", 120);
    assert_script_run("yes '' | easyrsa gen-req client nopass", 120);
    assert_script_run("echo 'yes' | easyrsa sign-req client client", 120);
    mutex_create 'OPENVPN_CA_KEYS';

    # Download the server config
    assert_script_run("curl -o ca.conf " . data_url("openvpn/ca_server.conf"));

    # Create the client config directory and the file for client
    assert_script_run("mkdir ccd");
    assert_script_run(qq(echo "ifconfig-push 10.8.0.2 255.255.255.0" > ccd/client));

    # Start the server
    systemctl('start openvpn@ca');
    systemctl('status openvpn@ca -l');

    # Make sure the tunnel has been established
    script_retry('journalctl --no-pager -u openvpn@ca | grep "Initialization Sequence Completed"', delay => 15, retry => 12);

    # Test that the interface is present
    assert_script_run("ip a s tap0");
    assert_script_run('ip a s tap0 | grep "10\.8\.0\.1"');

    # Test the connection when also the client is ready
    barrier_wait 'OPENVPN_CA_STARTED';
    assert_script_run("ping -c5 -W1 -I tap0 10.8.0.2");

    # Stop the server when also client is done
    barrier_wait 'OPENVPN_CA_FINISHED';
    systemctl('stop openvpn@ca');

    wait_for_children();
}

1;
