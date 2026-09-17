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
use Kernel::multimachine_topology qw(get_local_node get_remote_nodes get_interface get_network_by_id);
use Kernel::mikrotik_switch qw(add_vlan remove_vlan set_port_pvid);
use Kernel::net_tests qw(add_ipv4_addr get_net_prefix_len);

sub set_vlan {
    my ($node, $network) = @_;

    # Configures every node's port on this network, not just the caller's -
    # see run() below for why only one role ever calls this, to avoid two
    # concurrent jobs racing each other on the same REST calls.
    my @network_ports = map { get_interface($_, 0)->{switch_port} }
      grep { get_interface($_, 0)->{network} eq $network->{id} } ($node, @{get_remote_nodes($node)});
    my $untagged = join(',', @network_ports);

    my $vlan_id = $network->{vlan_id};
    eval { remove_vlan($vlan_id) };
    add_vlan(bridge => 'bridge', vlan_id => $vlan_id, untagged => $untagged);
    set_port_pvid($_, $vlan_id) for @network_ports;
    record_info('Mikrotik VLAN', "VLAN $vlan_id recreated, untagged=[$untagged], PVID $vlan_id");
}

sub run {
    select_serial_terminal;

    my $node = get_local_node();
    my $interface = get_interface($node, 0);
    my $network = get_network_by_id($interface->{network});

    # Only one role provisions the switch
    set_vlan($node, $network) if get_var('ROLE') eq 'nvme_initiator';

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
C<BLKTESTS_NVME_REMOTE_TARGET>). Every role that schedules this module
assigns its own static IP, read from the C<multimachine_topology> test
data (see C<test_data/kernel/multimachine/nvme_tcp_2hosts.yaml>).

The shared VLAN on the Mikrotik switch (every peer's port as an untagged
member, not just the caller's) is provisioned by only the C<nvme_initiator>
role, since C<coppi> and C<merckx>'s jobs run in parallel with nothing
serializing them, and the switch-side delete-then-add isn't safe to run
from two concurrent callers at once.

The local node is resolved via C<Kernel::multimachine_topology::get_local_node>
(the C<ROLE> job variable).

=cut
