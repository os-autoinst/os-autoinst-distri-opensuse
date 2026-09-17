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
use Kernel::multimachine_topology qw(get_local_node get_interface get_network_by_id);
use Kernel::mikrotik_switch qw(add_vlan remove_vlan set_port_pvid);
use Kernel::net_tests qw(add_ipv4_addr get_net_prefix_len);

sub run {
    select_serial_terminal;

    my $node = get_local_node();
    my $interface = get_interface($node, 0);
    my $network = get_network_by_id($interface->{network});

    # Mikrotik switch VLAN is recreated on every run rather than checked for
    # existence first: add_vlan() deliberately dies on an existing VLAN id
    # (see Kernel::mikrotik_switch), so a plain delete-then-add is the
    # simplest way to keep this idempotent across job runs.
    my $vlan_id = $network->{vlan_id};
    my $switch_port = $interface->{switch_port};
    eval { remove_vlan($vlan_id) };
    add_vlan(bridge => 'bridge', vlan_id => $vlan_id, untagged => $switch_port);
    set_port_pvid($switch_port, $vlan_id);
    record_info('Mikrotik VLAN', "VLAN $vlan_id recreated, $switch_port set untagged/PVID $vlan_id");

    add_ipv4_addr(
        ip => $interface->{ipv4},
        dev => $interface->{dev},
        plen => get_net_prefix_len(net => $network->{ipv4_cidr}),
    );
    record_info('Local node', "assigned $interface->{ipv4} to $interface->{dev}");
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Prepares the network path for a multimachine C<blktests> run against a
real, separate NVMe target (see C<kernel/blktests>'s
C<BLKTESTS_NVME_REMOTE_TARGET>): (re)creates the local node's dedicated
VLAN on the Mikrotik switch and assigns its static IP, both read from the
C<multimachine_topology> test data (see
C<test_data/kernel/multimachine/nvme_tcp_2hosts.yaml>).

The local node is resolved via C<Kernel::multimachine_topology::get_local_node>
(the C<ROLE> job variable), so this module works for whichever role
schedules it - currently just C<nvme_initiator>, ahead of C<kernel/blktests>.

=cut
