# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: san_network_cleanup
# Summary: Remove the storage VLAN of the test from the Mikrotik switch
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use Kernel::multimachine_topology qw(get_local_node get_peers get_node_interface get_topology_network);
use Kernel::mikrotik_switch 'remove_vlan_network';

sub run {
    my $node = get_local_node();
    my $network = get_topology_network(get_node_interface($node, 0)->{network});
    my @ports = map { get_node_interface($_, 0)->{switch_port} } ($node, @{get_peers($node)});
    remove_vlan_network(vlan_id => $network->{vlan_id}, ports => \@ports);
}

1;

=head1 Description

Removes the VLAN that C<kernel/san_network> created and sets the switch
ports back to their default VLAN 3. Schedule it as the last module, so
that it also runs after a failed test.

=cut
