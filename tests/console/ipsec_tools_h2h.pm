
# SUSE's Racoon tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: ipsec-tools iproute2
# Summary: Test Racoon host-to-host scenario
# Maintainer: Ben Chou <bchou@suse.com>

use strict;
use warnings;
use base "consoletest";
use lockapi;
use testapi;
use utils;
use mmapi;
use mm_network;

sub run {
    my $self = shift;
    select_console 'root-console';
    my $is_ipsec_primary = get_var('IPSEC_PRIMARY');

    # Static IP address for Primary host and secondary host
    my $ipsec_primary_ip = "10.0.2.49/15";
    my $ipsec_secondary_ip = "10.0.2.50/15";
    my $my_static_ip = $is_ipsec_primary ? $ipsec_primary_ip : $ipsec_secondary_ip;

    # install ipsec-tools and config gateway and static ip on worker
    configure_default_gateway;
    configure_static_ip(ip => $my_static_ip);
    configure_static_dns(get_host_resolv_conf());
    restart_networking();
    zypper_call 'in ipsec-tools';

    if ($is_ipsec_primary) {
        set_config($is_ipsec_primary, $ipsec_primary_ip, $ipsec_secondary_ip);
        my $children = get_children();
        my $child_id = (keys %$children)[0];
        mutex_create('ipsec_primary');
        wait_for_children;
    }
    else {
        my ($primary) = split('/', $ipsec_primary_ip);
        set_config($is_ipsec_primary, $ipsec_secondary_ip, $ipsec_primary_ip);
        mutex_lock('ipsec_primary');
        mutex_unlock('ipsec_primary');

        # Test the secure channel, ping primary from secondary
        assert_script_run "ping -c 10 $primary";
    }
}

# Get pre-generated certs and config template for primary and secondary

sub set_config {
    my ($is_primary, $host_ip, $remote_ip) = @_;

    # Split subnet mask
    my ($host) = split('/', $host_ip);
    my ($remote) = split('/', $remote_ip);
    my $cert = $is_primary ? "server" : "client";
    assert_script_run "ip route";
    assert_script_run "ip addr";
    assert_script_run "ping -c 6 10.0.2.2";
    my $mask = "32";

    # Download pre-generated certs
    assert_script_run "curl -f -v " . data_url('openssl/ca-cert.pem') . " > /etc/racoon/cert/ca-cert.pem";
    assert_script_run "curl -f -v " . data_url('openssl/ca-key.pem') . " > /etc/racoon/cert/ca-key.pem";
    assert_script_run "curl -f -v " . data_url("openssl/$cert-cert.pem") . "> /etc/racoon/cert/$cert-cert.pem";
    assert_script_run "curl -f -v " . data_url("openssl/$cert-key.pem") . " > /etc/racoon/cert/$cert-key.pem";

    # Download config template
    assert_script_run "curl -f -v " . data_url("racoon/racoon.conf") . "> /etc/racoon/racoon.conf";
    assert_script_run "curl -f -v " . data_url("racoon/setkey.conf") . " > /etc/racoon/setkey.conf";

    # Fill in ip address to the config template
    assert_script_run "sed -i 's/RemoteIP/$remote/' /etc/racoon/racoon.conf";
    assert_script_run "sed -i 's/listenIP/$host/' /etc/racoon/racoon.conf";
    assert_script_run "sed -i 's/RemoteIP/$remote\\\/$mask/' /etc/racoon/setkey.conf";
    assert_script_run "sed -i 's/HostIP/$host\\\/$mask/' /etc/racoon/setkey.conf";
    assert_script_run "sed -i 's/Remote/$remote/' /etc/racoon/setkey.conf";
    assert_script_run "sed -i 's/Host/$host/' /etc/racoon/setkey.conf";
    assert_script_run "sed -i 's/HOST/$cert/g' /etc/racoon/racoon.conf";

    # Stop Firewall
    assert_script_run "SUSEfirewall2 off";

    # Start racoon service
    systemctl 'start racoon.service';
    assert_script_run "setkey -f /etc/racoon/setkey.conf";
}
1;
