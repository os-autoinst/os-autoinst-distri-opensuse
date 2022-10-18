#SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test IPsec tunnel in Open vSwitch with 3 different authentication methods
#
#   This test does the following
#    - Installs openvswitch-ipsec, openvswitch-pki and openvswitch-vtep
#    - Starts the systemd service unit
#    - Executes IPsec tunneling between two hosts with the following authenitcation
#    methods:
#       * Pre-shared key
#       * Self-signed certificate
#       * CA-signed certificate
#    - Sets up and starts the VTEP emulator
#    - Sets up the logical network, where server and client connect to one switch
#    - Verifies that client can ping the server
#
# Maintainer: Anna Minou <anminou@suse.de>
#
use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use console::ovs_utils;


my $server_ip = "10.0.2.101";
my $client_ip = "10.0.2.102";
my $server_vpn = "192.0.0.1";
my $client_vpn = "192.0.0.2";
my $server_mac = "00:00:00:00:00:01";
my $client_mac = "00:00:00:00:00:02";
my $dir = "/etc/keys/";
my $dir_certs = "/etc/ipsec.d/certs/";
my $dir_private = "/etc/ipsec.d/private/";
my $dir_cacerts = "/etc/ipsec.d/cacerts/";

sub run {

    my ($self) = @_;
    select_serial_terminal;

    mutex_wait 'barrier_setup_done';

    # Install the needed packages
    zypper_call('in openvswitch-ipsec openvswitch-pki tcpdump openvswitch-vtep', timeout => 300);

    # Start the openvswitch and openvswitch-ipsec services
    systemctl 'start openvswitch', timeout => 200;
    systemctl 'start openvswitch-ipsec', timeout => 200;

    # Setup ovs bridge
    add_bridge("$client_vpn");

    # Set IPsec tunnel using pre-shared key
    assert_script_run("ovs-vsctl add-port br-ipsec tun -- set interface tun type=gre options:remote_ip=$server_ip options:psk=swordfish");
    systemctl 'restart openvswitch-ipsec';
    systemctl 'status openvswitch-ipsec';

    # Wait till both hosts have finished the IPsec setup
    barrier_wait 'ipsec_done';
    ping_check("$server_ip", "$client_ip", "$server_vpn");

    # Wait for the server to finish checking the sent ESP packets
    barrier_wait 'traffic_check_done';


    assert_script_run("ovs-vsctl del-br br-ipsec");
    add_bridge("$client_vpn");
    assert_script_run("mkdir -p $dir && cd $dir");

    # Set IPsec tunnel using self-signed certificate
    # Generate self-signed certificate
    assert_script_run("ovs-pki req -u host_2");
    assert_script_run("ovs-pki self-sign host_2");
    barrier_wait 'certificate_signed';

    # Copy the certificate to server
    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$server_ip");
    assert_script_run("scp -o StrictHostKeyChecking=no  host_2-cert.pem $server_ip:/etc/keys/host_2-cert.pem");

    barrier_wait 'cert_done';

    # Configure IPsec tunnel to use self-signed certificates
    assert_script_run("cp /etc/keys/host_2-cert.pem /etc/ipsec.d/certs/");
    assert_script_run("cp /etc/keys/host_2-privkey.pem /etc/ipsec.d/private/");
    assert_script_run("ovs-vsctl set Open_vSwitch . other_config:certificate=/etc/keys/host_2-cert.pem other_config:private_key=/etc/keys/host_2-privkey.pem");
    assert_script_run("ovs-vsctl add-port br-ipsec tun -- set interface tun type=gre options:remote_ip=$server_ip options:remote_cert=/etc/keys/host_1-cert.pem");
    systemctl 'restart openvswitch-ipsec';
    systemctl 'status openvswitch-ipsec';

    barrier_wait 'ipsec1_done';
    ping_check("$server_ip", "$client_ip", "$server_vpn");

    barrier_wait 'traffic_check_done1';

    assert_script_run("rm -r $dir* $dir_certs* $dir_private*");

    barrier_wait 'empty_directories';

    assert_script_run("ovs-vsctl del-br br-ipsec");
    add_bridge("$client_vpn");

    # Set IPsec tunnel using CA-signed certificate
    # Generate certificate request and send it to server
    assert_script_run("cd $dir");
    assert_script_run("ovs-pki req -u host_2");
    assert_script_run("scp -o StrictHostKeyChecking=no host_2-req.pem $server_ip:/etc/keys/host_2-req.pem");

    # Wait for the certificate to be sent back with the CA certificate
    barrier_wait 'host2_cert_ready';
    barrier_wait 'cacert_done';

    # Configure IPsec tunnel to use CA-signed certificate
    assert_script_run("cp host_2-cert.pem $dir_certs");
    assert_script_run("cp host_2-privkey.pem $dir_private");
    assert_script_run("cp cacert.pem $dir_cacerts");
    assert_script_run("ovs-vsctl set Open_vSwitch . other_config:certificate=/etc/keys/host_2-cert.pem other_config:private_key=/etc/keys/host_2-privkey.pem other_config:ca_cert=/etc/keys/cacert.pem");
    assert_script_run("ovs-vsctl add-port br-ipsec tun -- set interface tun type=gre options:remote_ip=$server_ip options:remote_name=host_1");
    systemctl 'restart openvswitch-ipsec';
    systemctl 'status openvswitch-ipsec';

    barrier_wait 'ipsec2_done';
    ping_check("$server_ip", "$client_ip", "$server_vpn");

    barrier_wait 'traffic_check_done2';

    assert_script_run("ovs-vsctl del-br br-ipsec");
    assert_script_run("rm -r $dir* $dir_certs* $dir_private*");

    barrier_wait 'end_of_test';

    systemctl 'stop ovsdb-server';
    systemctl 'stop ovs-vswitchd';

    # Create the ovs and vtep schemas
    assert_script_run("ovsdb-tool create /etc/openvswitch/ovs.db /usr/share/openvswitch/vswitch.ovsschema");
    assert_script_run("ovsdb-tool create /etc/openvswitch/vtep.db /usr/share/openvswitch/vtep.ovsschema");

    # Start ovsdb-server and have it handle both databases
    assert_script_run("ovsdb-server --pidfile --detach --log-file --remote punix:/var/run/openvswitch/db.sock --remote=db:hardware_vtep,Global,managers /etc/openvswitch/ovs.db /etc/openvswitch/vtep.db");

    # Start ovs-vswitchd as normal
    assert_script_run("ovs-vswitchd --log-file --detach --pidfile unix:/var/run/openvswitch/db.sock");

    # Set up the vtep emulator
    assert_script_run("ovs-vsctl add-br br0");
    assert_script_run("ovs-vsctl add-port br0 p1 -- set interface p1 type=internal");
    assert_script_run("ip link set dev p1 address $client_mac");
    assert_script_run("ip a add $client_vpn/24 dev p1");
    assert_script_run("ip link set dev p1 up");

    # Start VTEP Emulator
    assert_script_run("vtep-ctl add-ps br0");
    assert_script_run("vtep-ctl set Physical_Switch br0 tunnel_ips=$client_ip");
    script_output("/usr/share/openvswitch/scripts/ovs-vtep --log-file --pidfile --detach br0");

    # Verify that the ovs-vtep script has run
    script_retry('cat /var/log/openvswitch/ovs-vtep.log | grep ovs-vtep', delay => 5, retry => 5);

    # Set up Logical Network for the server and client
    assert_script_run("vtep-ctl add-ls ls0");
    assert_script_run("vtep-ctl set Logical_Switch ls0 tunnel_key=5000");
    assert_script_run("vtep-ctl bind-ls br0 p1 0 ls0");
    assert_script_run("vtep-ctl add-ucast-remote ls0 $server_mac  $server_ip");

    # Direct unknown destinations out a tunnel
    assert_script_run("vtep-ctl add-mcast-remote ls0 unknown-dst $server_ip");

    # Wait for the server to finish the configuration
    barrier_wait 'vtep_config';

    assert_script_run("ping -I p1 -c 5 $server_vpn");

    barrier_wait 'end';
}

1;

