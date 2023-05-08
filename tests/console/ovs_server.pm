# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test IPsec tunnel in Open vSwitch with 3 different authentication methods
# and ovs-vtep in a VXLAN topology
#   This test does the following
#    - Installs openvswitch-ipsec, openvswitch-pki and openvswitch-vtep
#    - Starts the systemd service unit
#    - Executes IPsec tunneling between two hosts with the following authenitcation
#    methods:
#    	* Pre-shared key
#    	* Self-signed certificate
#    	* CA-signed certificate
#    - This host verifies that IPsec GRE tunnel is running between the two hosts
#    - Sets up and starts the VTEP emulator
#    - Sets up the logical network, where server and client connect to one switch
#    - Verifies that server can ping the client
#
# Maintainer: Anna Minou <anminou@suse.de>
#
use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use console::ovs_utils;
use version_utils;

my $server_ip = "10.0.2.101";
my $client_ip = "10.0.2.102";
my $client_vpn = "192.0.0.2";
my $server_vpn = "192.0.0.1";
my $server_mac = "00:00:00:00:00:01";
my $client_mac = "00:00:00:00:00:02";
my $dir = "/etc/keys/";
my $dir_certs = "/etc/ipsec.d/certs/";
my $dir_private = "/etc/ipsec.d/private/";
my $dir_cacerts = "/etc/ipsec.d/cacerts/";

sub run {

    my ($self) = @_;
    select_serial_terminal;

    barrier_create('ipsec_done', 2);
    barrier_create('traffic_check_done', 2);
    barrier_create('certificate_signed', 2);
    barrier_create('ipsec1_done', 2);
    barrier_create('traffic_check_done1', 2);
    barrier_create('ipsec2_done', 2);
    barrier_create('traffic_check_done2', 2);
    barrier_create('cert_done', 2);
    barrier_create('host2_cert_ready', 2);
    barrier_create('empty_directories', 2);
    barrier_create('cacert_done', 2);
    barrier_create('end_of_test', 2);
    barrier_create('vtep_config', 2);
    barrier_create('end', 2);
    mutex_create 'barrier_setup_done';

    # Install the needed packages
    # At moment we have opnvswitch3* packages on sles 15 sp5 only, so take care of update test as well
    if (is_sle('>=15-SP5') || check_var('FLAVOR', 'Server-DVD-Updates')) {
        zypper_call('in openvswitch3-ipsec tcpdump openvswitch3-pki openvswitch3-vtep', timeout => 300);
    }
    else {
        zypper_call('in openvswitch-ipsec tcpdump openvswitch-pki openvswitch-vtep', timeout => 300);
    }
    systemctl 'start openvswitch', timeout => 200;
    systemctl 'start openvswitch-ipsec', timeout => 200;

    # Setup the ovs bridge
    add_bridge("$server_vpn");

    # Setup IPsec tunnel using pre-shared keys
    assert_script_run("ovs-vsctl add-port br-ipsec tun -- set interface tun type=gre options:remote_ip=$client_ip options:psk=swordfish");
    systemctl 'restart openvswitch-ipsec';
    systemctl 'status openvswitch-ipsec';

    # Wait for the client host to setup the IPsec tunnel
    barrier_wait 'ipsec_done';

    # Check that ESP packets are being sent from this host(server) to the other(client)
    ping_check("$server_ip", "$client_ip", "$client_vpn");

    # Wait until the check for the ESP packets is done
    barrier_wait 'traffic_check_done';

    assert_script_run("ovs-vsctl del-br br-ipsec");
    add_bridge("$server_vpn");
    assert_script_run("mkdir -p $dir && cd $dir");

    # Setup IPsec tunnel using self-signed certificate
    # Generate self-signed certificate
    assert_script_run("ovs-pki req -u host_1");
    assert_script_run("ovs-pki self-sign host_1");
    barrier_wait 'certificate_signed';

    # Copy the certificate to client host
    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$client_ip");
    assert_script_run("scp -o StrictHostKeyChecking=no  host_1-cert.pem $client_ip:/etc/keys/host_1-cert.pem");

    barrier_wait 'cert_done';

    # Configure IPsec tunnel to use self-signed certificates
    assert_script_run("cp host_1-cert.pem $dir_certs");
    assert_script_run("cp host_1-privkey.pem $dir_private");
    assert_script_run("ovs-vsctl set Open_vSwitch . other_config:certificate=/etc/keys/host_1-cert.pem other_config:private_key=/etc/keys/host_1-privkey.pem");
    assert_script_run("ovs-vsctl add-port br-ipsec tun -- set interface tun type=gre options:remote_ip=$client_ip options:remote_cert=/etc/keys/host_2-cert.pem");
    systemctl 'restart openvswitch-ipsec';
    systemctl 'status openvswitch-ipsec';

    # Wait for the client host to setup the IPsec tunnel
    barrier_wait 'ipsec1_done';

    # Check that ESP packets are being sent from this host(server) to the other(client)
    ping_check("$server_ip", "$client_ip", "$client_vpn");

    barrier_wait 'traffic_check_done1';

    assert_script_run("rm -r $dir* $dir_certs* $dir_private*");
    barrier_wait 'empty_directories';

    assert_script_run("ovs-vsctl del-br br-ipsec");
    add_bridge("$server_vpn");

    barrier_wait 'host2_cert_ready';

    # Setup IPsec tunnel using CA-signed certificate
    assert_script_run("ovs-pki init");
    assert_script_run("cd $dir");

    # Generate and sign the certificate request with the CA key
    assert_script_run("ovs-pki req -u host_1");
    assert_script_run("ovs-pki -b sign host_1 switch");

    # Wait for the client to send the certificate request and sign it with the CA key

    assert_script_run("ovs-pki -b sign host_2 switch");

    # Copy the client's certificate and CA certificate to client
    assert_script_run("scp -o StrictHostKeyChecking=no  host_2-cert.pem root\@$client_ip:/etc/keys/host_2-cert.pem");
    assert_script_run("scp /var/lib/openvswitch/pki/switchca/cacert.pem root\@$client_ip:/etc/keys/cacert.pem");
    barrier_wait 'cacert_done';

    # Configure IPsec tunnel to use CA-signed certificate
    assert_script_run("cp /var/lib/openvswitch/pki/switchca/cacert.pem $dir");
    assert_script_run("cp /var/lib/openvswitch/pki/switchca/cacert.pem $dir_cacerts");
    assert_script_run("cp host_1-cert.pem $dir_certs");
    assert_script_run("cp host_1-privkey.pem $dir_private");

    assert_script_run("ovs-vsctl set Open_vSwitch . other_config:certificate=/etc/keys/host_1-cert.pem other_config:private_key=/etc/keys/host_1-privkey.pem other_config:ca_cert=/etc/keys/cacert.pem");
    assert_script_run("ovs-vsctl add-port br-ipsec tun -- set interface tun type=gre options:remote_ip=$client_ip options:remote_name=host_2");
    systemctl 'restart openvswitch-ipsec';
    systemctl 'status openvswitch-ipsec';

    barrier_wait 'ipsec2_done';

    ping_check("$server_ip", "$client_ip", "$client_vpn");

    barrier_wait 'traffic_check_done2';

    assert_script_run("ovs-vsctl del-br br-ipsec");
    assert_script_run("rm -r $dir* $dir_certs* $dir_private* $dir_cacerts*");

    barrier_wait 'end_of_test';

    systemctl 'stop ovsdb-server';
    systemctl 'stop ovs-vswitchd';

    # Create vtep and ovs schemas
    assert_script_run("ovsdb-tool create /etc/openvswitch/ovs.db /usr/share/openvswitch/vswitch.ovsschema");
    assert_script_run("ovsdb-tool create /etc/openvswitch/vtep.db /usr/share/openvswitch/vtep.ovsschema");

    # Start ovsdb-server and have it handle both databases
    assert_script_run("ovsdb-server --pidfile --detach --log-file --remote punix:/var/run/openvswitch/db.sock --remote=db:hardware_vtep,Global,managers /etc/openvswitch/ovs.db /etc/openvswitch/vtep.db");

    # Start ovs-vswitchd as normal
    assert_script_run("ovs-vswitchd --log-file --detach --pidfile unix:/var/run/openvswitch/db.sock");

    # Set up the emulator
    assert_script_run("ovs-vsctl add-br br0");
    assert_script_run("ovs-vsctl add-port br0 p0 -- set interface p0 type=internal");
    assert_script_run("ip link set dev p0 address $server_mac");
    assert_script_run("ip a add $server_vpn/24 dev p0");
    assert_script_run("ip link set dev p0 up");

    # Start VTEP emulator
    assert_script_run("vtep-ctl add-ps br0");
    assert_script_run("vtep-ctl set Physical_Switch br0 tunnel_ips=$server_ip");
    script_output("/usr/share/openvswitch/scripts/ovs-vtep --log-file --pidfile --detach br0");

    # Verify that the ovs-vtep script has run
    script_retry('cat /var/log/openvswitch/ovs-vtep.log | grep ovs-vtep', delay => 5, retry => 5);

    # Set up a logical Network for server and client
    assert_script_run("vtep-ctl add-ls ls0");
    assert_script_run("vtep-ctl set Logical_Switch ls0 tunnel_key=5000");
    assert_script_run("vtep-ctl bind-ls br0 p0 0 ls0");
    assert_script_run("vtep-ctl add-ucast-remote ls0 $client_mac $client_ip");

    # Direct unknown destinations out a tunnel.
    assert_script_run("vtep-ctl add-mcast-remote ls0 unknown-dst $client_ip");

    # Wait for the client to finish the configuration
    barrier_wait 'vtep_config';

    assert_script_run("ping -I p0 -c 5 $client_vpn");

    barrier_wait 'end';

}

1;
