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
use Kernel::multimachine_topology qw(get_local_node get_peers get_node_interface get_topology_network);
use Kernel::mikrotik_switch qw(create_vlan_network remove_vlan_network);
use Kernel::net_tests qw(set_link_up add_ipv4_addr get_net_prefix_len);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $node = get_local_node();
    my $interface = get_node_interface($node, 0);
    my $network = get_topology_network($interface->{network});
    my @ports = map { get_node_interface($_, 0)->{switch_port} } ($node, @{get_peers($node)});
    create_vlan_network(vlan_id => $network->{vlan_id}, ports => \@ports);
    $self->{vlan} = {vlan_id => $network->{vlan_id}, ports => \@ports};

    # NetworkManager must not reset the interface, for example after a
    # failed DHCP request, because that removes the static address.
    script_run("nmcli device set $interface->{device} managed no");
    set_link_up($interface->{device});
    add_ipv4_addr(
        ip => $interface->{ipv4},
        dev => $interface->{device},
        plen => get_net_prefix_len(net => $network->{ipv4_cidr}),
    );
}

# The module is fatal, so kernel/san_network_cleanup does not run after a
# failure. Remove the VLAN here, but only if this module created it, not
# the VLAN of another test. This works also if the SUT does not answer,
# because the switch calls run from the worker.
sub post_fail_hook {
    my ($self) = @_;
    if (my $vlan = delete $self->{vlan}) {
        eval { remove_vlan_network(%$vlan) };
        record_info('VLAN cleanup', $@, result => 'fail') if $@;
    }
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Creates an isolated network for the test on the Mikrotik switch: a new
VLAN from the C<multimachine_topology> test data with the switch ports of
all nodes as untagged members. Then adds the address of the local node.
Dies if the VLAN already exists, for example because another test uses
it. C<kernel/san_network_cleanup> removes the network.

=cut
