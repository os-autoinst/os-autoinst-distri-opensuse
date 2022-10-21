# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openvpn openssh iputils
# Summary: Test OpenVPN on two machines. This one is client.
#  * After server is done, we use SCP to download the shared key
#  * When connected, we perform the ping, disconnect and wait again
#  * After server is done, we use SCP to download the root certificate, client certificate and key
#  * When connected, we perform the ping, and finally disconnect.
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use y2_module_guitest;
use mm_network;
use utils qw(systemctl zypper_call exec_and_insert_password script_retry);
use strict;
use warnings;

sub run {
    mutex_wait 'barrier_setup_done';
    barrier_wait 'SETUP_DONE';
    select_serial_terminal;

    # Install openvpn
    zypper_call('in openvpn');
    assert_script_run('cd /etc/openvpn');

    # Wait for static key and write the client config
    mutex_wait 'OPENVPN_STATIC_KEY';

    # Download the client config
    assert_script_run("curl -o static.conf " . data_url("openvpn/static_client.conf"));

    # Download key from the server
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/static.key /etc/openvpn/static.key");
    assert_script_run("cat /etc/openvpn/static.key");

    # Start the client when also server is ready and test the connection
    systemctl('start openvpn@static');
    systemctl('status openvpn@static -l');

    # Make sure the tunnel has been established
    script_retry('journalctl --no-pager -u openvpn@static | grep "Initialization Sequence Completed"', delay => 15, retry => 12);

    # Test that the interface is present
    assert_script_run('ip a s tun0');
    assert_script_run('ip a s tun0 | grep "10\.8\.0\.2"');

    # Test the connection when both client and server are rady
    barrier_wait 'OPENVPN_STATIC_STARTED';
    assert_script_run("ping -c5 -W1 -I tun0 10.8.0.1");

    # Stop the client when also server is done
    barrier_wait 'OPENVPN_STATIC_FINISHED';
    systemctl('stop openvpn@static');

    # Download keys and certificates when they are on the server available
    mutex_wait 'OPENVPN_CA_KEYS';

    # Write the client config
    assert_script_run("curl -o ca.conf " . data_url("openvpn/ca_client.conf"));

    # Download key from the server
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/pki/ca.crt /etc/openvpn/ca.crt");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/pki/issued/client.crt /etc/openvpn/client.crt");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/pki/private/client.key /etc/openvpn/client.key");

    # Start the client when also server is ready and test the connection
    systemctl('start openvpn@ca');
    systemctl('status openvpn@ca -l');

    # Make sure the tunnel has been established
    script_retry('journalctl --no-pager -u openvpn@ca | grep "Initialization Sequence Completed"', delay => 15, retry => 12);

    # Test that the interface is present
    assert_script_run("ip a s tap0");
    assert_script_run('ip a s tap0 | grep "10\.8\.0\.2"');

    barrier_wait 'OPENVPN_CA_STARTED';
    assert_script_run("ping -c5 -W1 -I tap0 10.8.0.1");

    # Stop the client when also server is done
    barrier_wait 'OPENVPN_CA_FINISHED';
    systemctl('stop openvpn@ca');
}

1;
