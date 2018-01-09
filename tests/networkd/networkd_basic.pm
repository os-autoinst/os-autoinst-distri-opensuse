# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic Networkd test: Two nodes, DHCP Server/Client, IP assignment and communication
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'networkdbase';
use strict;
use testapi;
use utils qw(systemctl snapper_revert_system arrays_differ);

sub run {
    my ($self) = @_;

    # Setup node1 (DHCP Server)
    $self->assert_script_run_container("node1", "mkdir -p /etc/systemd/network");
    $self->write_container_file("node1", "/etc/systemd/network/50-static.network", "
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
");
    $self->assert_script_run_container("node1", "systemctl restart systemd-networkd");
    $self->assert_script_run_container("node1", "ip a");
    $self->assert_script_run_container("node1", "networkctl");
    # wait until network is configured
    $self->assert_script_run_container("node1", "for i in {1..20} ; do networkctl | grep host0.*configured && break ; sleep 1 ; done");
    $self->assert_script_run_container("node1", "networkctl");
    $self->assert_script_run_container("node1", "networkctl | grep host0.*configured");
    $self->assert_script_run_container("node1", "networkctl status");


    # Setup node2 (DHCP Client)
    $self->assert_script_run_container("node2", "mkdir -p /etc/systemd/network");
    $self->write_container_file("node2", "/etc/systemd/network/50-dhcp.network", "
[Match]
Name=host0

[Network]
DHCP=ipv4
");
    $self->assert_script_run_container("node2", "systemctl restart systemd-networkd");
    $self->assert_script_run_container("node2", "ip a");
    $self->assert_script_run_container("node2", "networkctl");
    # wait until network is configured
    $self->assert_script_run_container("node2", "for i in {1..20} ; do networkctl | grep host0.*configured && break ; sleep 1 ; done");
    $self->assert_script_run_container("node2", "networkctl");
    $self->assert_script_run_container("node2", "networkctl | grep host0.*configured");
    $self->assert_script_run_container("node2", "networkctl status");
    $self->assert_script_run_container("node2", "ping -c1 44.0.0.1");
}

1;
