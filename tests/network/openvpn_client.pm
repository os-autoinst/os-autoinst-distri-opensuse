# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test OpenVPN on two machines. This one is client.
#  * After server is done, we use SCP to download the shared key
#  * When connected, we perform the ping, disconnect and wait again
#  * After server is done, we use SCP to download the root certificate, client certificate and key
#  * When connected, we perform the ping, and finally disconnect.
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use lockapi;
use y2_module_guitest;
use mm_network;
use utils qw(systemctl zypper_call exec_and_insert_password);
use strict;
use warnings;

sub run {
    select_console "root-console";

    # Install openvpn
    zypper_call('in openvpn');
    assert_script_run('cd /etc/openvpn');

    # Wait for static key and write the client config
    mutex_wait 'OPENVPN_STATIC_KEY';
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/static.key /etc/openvpn/static.key");
    assert_script_run("cat /etc/openvpn/static.key");
    assert_script_run(qq(echo "remote 10.0.2.101
dev tun
ifconfig 10.8.0.2 10.8.0.1
secret /etc/openvpn/static.key" > static.conf));

    # Start the client when also server is ready and test the connection
    barrier_wait 'OPENVPN_STATIC_START';
    systemctl('start openvpn@static');
    systemctl('status openvpn@static -l');

    # Test the connection when both client and server are rady
    barrier_wait 'OPENVPN_STATIC_STARTED';
    assert_script_run("ping -c5 -W1 -I tun0 10.8.0.1");

    # Stop the client when also server is done
    barrier_wait 'OPENVPN_STATIC_FINISHED';
    systemctl('stop openvpn@static');

    # Download keys and certificates when they are on the server available
    mutex_wait 'OPENVPN_CA_KEYS';
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/pki/ca.crt /etc/openvpn/ca.crt");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/pki/issued/client.crt /etc/openvpn/client.crt");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@10.0.2.101:/etc/openvpn/pki/private/client.key /etc/openvpn/client.key");

    # Write the client config
    assert_script_run(qq(echo "dev tap
remote 10.0.2.101 1194
tls-client
remote-cert-tls server

ca ca.crt
cert client.crt
key client.key

pull" > ca.conf));

    # Start the client when also server is ready and test the connection
    barrier_wait 'OPENVPN_CA_START';
    systemctl('start openvpn@ca');
    systemctl('status openvpn@ca -l');

    barrier_wait 'OPENVPN_CA_STARTED';
    assert_script_run("ping -c5 -W1 -I tap0 10.8.0.1");

    # Stop the client when also server is done
    barrier_wait 'OPENVPN_CA_FINISHED';
    systemctl('stop openvpn@ca');
}

1;
