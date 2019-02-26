# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test static bridge configuration using networkd
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
Name=br0
Kind=bridge
";

    my $network_base_file = "
[Match]
Name=host0

[Network]
Bridge=br0
";

    # Setup node1
    $self->write_container_file("node1", "/etc/systemd/network/br0.netdev",        $netdev_file);
    $self->write_container_file("node1", "/etc/systemd/network/10-bridge.network", $network_base_file);
    $self->write_container_file(
        "node1", "/etc/systemd/network/50-static.network", "
[Match]
Name=br0

[Network]
Address=44.0.0.1/24
"
    );

    $self->assert_script_run_container("node1", "systemctl restart systemd-networkd");
    # Workaround for gh#systemd/systemd#5043
    $self->wait_for_networkd("node1", "br0");


    # Setup node2
    $self->write_container_file("node2", "/etc/systemd/network/br0.netdev",        $netdev_file);
    $self->write_container_file("node2", "/etc/systemd/network/10-bridge.network", $network_base_file);
    $self->write_container_file(
        "node2", "/etc/systemd/network/50-static.network", "
[Match]
Name=br0

[Network]
Address=44.0.0.2/24
"
    );

    $self->assert_script_run_container("node2", "systemctl restart systemd-networkd");
    # Workaround for gh#systemd/systemd#5043
    $self->wait_for_networkd("node2", "br0");
    $self->assert_script_run_container("node2", "bridge link");
    $self->assert_script_run_container("node2", "ping -c1 44.0.0.1");


    # cleanup
    $self->assert_script_run_container("node1", "rm /etc/systemd/network/10-bridge.network");
    $self->assert_script_run_container("node2", "rm /etc/systemd/network/10-bridge.network");
    $self->assert_script_run_container("node1", "rm /etc/systemd/network/50-static.network");
    $self->assert_script_run_container("node2", "rm /etc/systemd/network/50-static.network");
    $self->assert_script_run_container("node1", "rm /etc/systemd/network/br0.netdev");
    $self->assert_script_run_container("node2", "rm /etc/systemd/network/br0.netdev");

    $self->restart_nspawn_container("node1");
    $self->restart_nspawn_container("node2");
}

1;
