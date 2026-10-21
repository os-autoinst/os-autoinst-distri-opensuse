# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: san_network
# Summary: Set up the storage VLAN on the Mikrotik switch and the SUT address
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Kernel::multimachine_topology qw(get_local_node get_peers get_job_nodes get_node_interface get_topology_network);
use Kernel::mikrotik_switch qw(create_vlan_network add_vlan_ports wait_for_vlan remove_vlan_network);
use Kernel::net_tests qw(set_link_up add_ipv4_addr get_net_prefix_len);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $node = get_local_node();
    my $interface = get_node_interface($node, 0);
    my $network = get_topology_network($interface->{network});
    my $vlan_id = $network->{vlan_id};
    my $dev = $interface->{device};
    my $port = $interface->{switch_port};
    record_info('Network before', script_output('ip -br addr; ip route'));

    # The test NIC can have a lab address from DHCP, in the same subnet as
    # the management NIC. Remove it before its switch port moves, so that
    # the connection of openQA to the SUT uses only the management NIC.
    # Keep NetworkManager off the NIC, so that it does not reset the static
    # address later.
    script_run("nmcli device disconnect $dev; nmcli device set $dev managed no; ip addr flush dev $dev");

    # The first job node creates the VLAN with its own port and the ports of
    # the external nodes, for example a storage appliance. Each other job
    # node adds only its own port, after it released its own test NIC.
    if ($node->{id} eq get_job_nodes()->[0]{id}) {
        my @external_ports = map { get_node_interface($_, 0)->{switch_port} } grep { $_->{external} } @{get_peers($node)};
        create_vlan_network(vlan_id => $vlan_id, ports => [$port, @external_ports]);
        $self->{vlan_created} = 1;
    } else {
        wait_for_vlan(vlan_id => $vlan_id);
        add_vlan_ports(vlan_id => $vlan_id, ports => [$port]);
    }

    set_link_up($dev);
    add_ipv4_addr(
        ip => $interface->{ipv4},
        dev => $dev,
        plen => get_net_prefix_len(net => $network->{ipv4_cidr}),
    );
    record_info('Network after', script_output('ip -br addr; ip route'));
}

# The module is fatal, so kernel/san_network_cleanup does not run after a
# failure. Remove the VLAN here, but only if this module created it, not
# the VLAN of another test. This works also if the SUT does not answer,
# because the switch calls run from the worker.
sub post_fail_hook {
    my ($self) = @_;
    if (delete $self->{vlan_created}) {
        my $node = get_local_node();
        my $network = get_topology_network(get_node_interface($node, 0)->{network});
        my @ports = map { get_node_interface($_, 0)->{switch_port} } ($node, @{get_peers($node)});
        eval { remove_vlan_network(vlan_id => $network->{vlan_id}, ports => \@ports) };
        record_info('VLAN cleanup', $@, result => 'fail') if $@;
    }
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Creates an isolated network for the test on the Mikrotik switch: a VLAN
from the C<multimachine_topology> test data with the switch ports of all
nodes as untagged members. Then adds the address of the local node.

The first job node in the topology creates the VLAN, with its own port and
the ports of the external nodes. It dies if the VLAN already exists, for
example because another test uses it. Each other job node waits for the
VLAN and adds its own port. So each job moves only the port of its own
test NIC.

Before the switch port of the local node moves, the module removes any
other address from its test NIC, for example a lab address from DHCP.
Otherwise the SUT can send part of the openQA traffic over the test NIC,
and the connection of openQA to the SUT breaks when the port moves.

C<kernel/san_network_cleanup> removes the network.

=cut
