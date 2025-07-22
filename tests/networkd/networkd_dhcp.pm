# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic Networkd test: Two nodes, DHCP Server/Client, IP assignment and communication
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'networkdbase';
use testapi;
use utils;

sub run {
    my ($self) = @_;

    # Setup node1 (DHCP Server)
    $self->write_container_file(
        "node1", "/etc/systemd/network/50-static.network", "
[Match]
Name=host0

[Network]
Address=44.0.0.1/24
Gateway=44.0.0.1
DHCPServer=yes

[DHCPServer]
PoolOffset=100
PoolSize=20
EmitDNS=yes
DNS=8.8.8.8
"
    );

    $self->assert_script_run_container("node1", "systemctl restart systemd-networkd");
    $self->wait_for_networkd("node1", "host0");


    # Setup node2 (DHCP Client)
    $self->write_container_file(
        "node2", "/etc/systemd/network/50-dhcp.network", "
[Match]
Name=host0

[Network]
DHCP=ipv4
"
    );

    $self->assert_script_run_container("node2", "systemctl restart systemd-networkd");
    $self->wait_for_networkd("node2", "host0");
    $self->assert_script_run_container("node2", "ping -c1 44.0.0.1");


    # cleanup
    $self->assert_script_run_container("node1", "rm /etc/systemd/network/50-static.network");
    $self->assert_script_run_container("node2", "rm /etc/systemd/network/50-dhcp.network");

    $self->restart_nspawn_container("node1");
    $self->restart_nspawn_container("node2");
}

1;
