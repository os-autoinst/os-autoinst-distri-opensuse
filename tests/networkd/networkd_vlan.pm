# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test static VLAN configuration using networkd
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'networkdbase';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $netdev_file = "
[NetDev]
Name=host0.42
Kind=vlan

[VLAN]
Id=42
";

    my $network_base_file = "
[Match]
Name=host0

[Network]
VLAN=host0.42
";

    # Setup node1
    $self->write_container_file("node1", "/etc/systemd/network/host0.42.netdev",   $netdev_file);
    $self->write_container_file("node1", "/etc/systemd/network/50-static.network", $network_base_file);
    $self->write_container_file(
        "node1", "/etc/systemd/network/host0.42.network", "
[Match]
Name=host0.42

[Network]
Description=\"VLAN 42\"
Address=44.0.0.1/24
"
    );

    $self->assert_script_run_container("node1", "systemctl restart systemd-networkd");
    $self->wait_for_networkd("node1", "host0");


    # Setup node2
    $self->write_container_file("node2", "/etc/systemd/network/host0.42.netdev",   $netdev_file);
    $self->write_container_file("node2", "/etc/systemd/network/50-static.network", $network_base_file);
    $self->write_container_file(
        "node2", "/etc/systemd/network/host0.42.network", "
[Match]
Name=host0.42

[Network]
Description=\"VLAN 42\"
Address=44.0.0.2/24
"
    );

    $self->assert_script_run_container("node2", "systemctl restart systemd-networkd");
    $self->wait_for_networkd("node2", "host0");
    $self->assert_script_run_container("node2", "ping -c1 44.0.0.1");


    # cleanup
    $self->assert_script_run_container("node1", "rm /etc/systemd/network/50-static.network");
    $self->assert_script_run_container("node2", "rm /etc/systemd/network/50-static.network");
    $self->assert_script_run_container("node1", "rm /etc/systemd/network/host0.42.netdev");
    $self->assert_script_run_container("node2", "rm /etc/systemd/network/host0.42.netdev");
    $self->assert_script_run_container("node1", "rm /etc/systemd/network/host0.42.network");
    $self->assert_script_run_container("node2", "rm /etc/systemd/network/host0.42.network");

    $self->restart_nspawn_container("node1");
    $self->restart_nspawn_container("node2");
}

1;
