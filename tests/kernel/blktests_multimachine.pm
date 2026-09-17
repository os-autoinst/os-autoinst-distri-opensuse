# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: blktests_multimachine
# Summary: Network setup for multimachine blktests runs (Mikrotik VLAN + static IP)
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Kernel::multimachine_topology qw(get_local_node get_peers get_interface get_network_by_id);
use Kernel::mikrotik_switch qw(add_vlan remove_vlan set_port_pvid);
use Kernel::net_tests qw(add_ipv4_addr get_net_prefix_len);

sub run {
    select_serial_terminal;

    my $node = get_local_node();
    my $interface = get_interface($node, 0);
    my $network = get_network_by_id($interface->{network});

    # Configure every node's port on this network, not just the local one:
    # the switch is reachable over REST regardless of which node's job is
    # running, and add_vlan()/remove_vlan() deliberately aren't upserts (see
    # Kernel::mikrotik_switch), so a plain delete-then-add is the simplest
    # way to stay idempotent across runs. Doing only the local port would
    # mean whichever node's job runs second wipes the other's port out of
    # the VLAN table.
    my @network_ports = map { get_interface($_, 0)->{switch_port} }
      grep { get_interface($_, 0)->{network} eq $network->{id} } ($node, @{get_peers($node)});
    my $untagged = join(',', @network_ports);

    my $vlan_id = $network->{vlan_id};
    eval { remove_vlan($vlan_id) };
    add_vlan(bridge => 'bridge', vlan_id => $vlan_id, untagged => $untagged);
    set_port_pvid($_, $vlan_id) for @network_ports;
    record_info('Mikrotik VLAN', "VLAN $vlan_id recreated, untagged=[$untagged], PVID $vlan_id");

    add_ipv4_addr(
        ip => $interface->{ipv4},
        dev => $interface->{device},
        plen => get_net_prefix_len(net => $network->{ipv4_cidr}),
    );
    record_info('Local node', "assigned $interface->{ipv4} to $interface->{device}");
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Prepares the network path for a multimachine C<blktests> run against a
real, separate NVMe target (see C<kernel/blktests>'s
C<BLKTESTS_NVME_REMOTE_TARGET>): (re)creates the shared VLAN on the
Mikrotik switch with every peer's port as an untagged member (not just
the local node's), and assigns the local node's static IP. All of it is
read from the C<multimachine_topology> test data (see
C<test_data/kernel/multimachine/nvme_tcp_2hosts.yaml>).

The local node is resolved via C<Kernel::multimachine_topology::get_local_node>
(the C<ROLE> job variable), so this module works for whichever role
schedules it - currently just C<nvme_initiator>, ahead of C<kernel/blktests>.
Whichever node runs it configures the VLAN for the whole topology, so it's
safe (if redundant) for more than one role to schedule it.

=cut
