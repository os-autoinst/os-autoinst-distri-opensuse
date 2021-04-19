#SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test IPsec tunnel in Open vSwitch with 3 different authentication methods
#
#   This test does the following
#    - Installs openvswitch-ipsec and openvswitch-pki
#    - Starts the systemd service unit
#    - Executes IPsec tunneling between two hosts with the following authenitcation
#    methods:
#       * Pre-shared key
#       * Self-signed certificate
#       * CA-signed certificate
#
# Maintainer: Anna Minou <anminou@suse.de>
#
use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use console::ovs_utils;


my $server_ip   = "10.0.2.101";
my $client_ip   = "10.0.2.102";
my $server_vpn  = "192.0.0.1";
my $client_vpn  = "192.0.0.2";
my $dir         = "/etc/keys/";
my $dir_certs   = "/etc/ipsec.d/certs/";
my $dir_private = "/etc/ipsec.d/private/";
my $dir_cacerts = "/etc/ipsec.d/cacerts/";

sub run {

    my ($self) = @_;
    $self->select_serial_terminal;

    # Install the needed packages
    zypper_call('in openvswitch-ipsec openvswitch-pki tcpdump', timeout => 300);

    # Start the openvswitch and openvswitch-ipsec services
    systemctl 'start openvswitch',       timeout => 200;
    systemctl 'start openvswitch-ipsec', timeout => 200;

    # Setup ovs bridge
    add_bridge("$client_vpn");

    # Set IPsec tunnel using pre-shared key
    assert_script_run("ovs-vsctl add-port br-ipsec tun -- set interface tun type=gre options:remote_ip=$server_ip options:psk=swordfish");
    systemctl 'restart openvswitch-ipsec';

    # Wait till both hosts have finished the IPsec setup
    barrier_wait 'ipsec_done';
    ping_check("$server_ip", "$client_ip", "$server_vpn");

    # Wait for the server to finish checking the sent ESP packets
    barrier_wait 'traffic_check_done';


    assert_script_run("ovs-vsctl del-br br-ipsec");
    add_bridge("$client_vpn");
    assert_script_run("mkdir $dir && cd $dir");

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

    barrier_wait 'ipsec2_done';
    ping_check("$server_ip", "$client_ip", "$server_vpn");

    barrier_wait 'traffic_check_done2';

    assert_script_run("ovs-vsctl del-br br-ipsec");
    assert_script_run("rm -r $dir* $dir_certs* $dir_private*");

    barrier_wait 'end_of_test';
}

1;

