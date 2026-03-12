# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Read and validate the multimachine topology of a test from the schedule test_data.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::multimachine_topology;

use strict;
use warnings;

use base 'Exporter';
use scheduler 'get_test_suite_data';
use testapi qw(get_required_var diag);

our @EXPORT_OK = qw(
  get_topology
  get_node_by_role
  get_local_node
  get_peers
  get_job_nodes
  get_topology_network
  get_node_interface
  require_field
);

=head1 NAME

Kernel::multimachine_topology - shared multimachine topology reader for test_data

=head1 SYNOPSIS

  use Kernel::multimachine_topology qw(get_local_node get_node_by_role get_node_interface);

  my $node = get_local_node();    # the node of this job, from ROLE
  my $ip = get_node_interface($node, 0)->{ipv4};
  my $peer_ip = get_node_interface(get_node_by_role('peer'), 0)->{ipv4};

=head1 DESCRIPTION

Reads the C<multimachine_topology> of a multimachine test from the
schedule C<test_data> and validates it. The topology describes the
machines of a setup: networks, and nodes with a role and interfaces. The
schedule includes it from a YAML file:

  test_data:
    <<: !include test_data/kernel/multimachine/irq_delivery_2hosts.yaml

See F<docs/KERNEL_BAREMETAL_MULTIMACHINE.md> for the format of the
topology, roles and external nodes, and how to write and run a test with
it.

This module only reads the topology; it does not change the system.

=cut

=head2 require_field

  my $value = require_field($field, 'field missing');

Return the provided value if it is defined and non-empty. Dies otherwise.

=cut

sub require_field {
    my ($value, $message) = @_;

    die $message unless defined $value && $value ne '';
    return $value;
}

sub _build_topology_index {
    my ($topology) = @_;
    my $nodes = require_field($topology->{nodes}, 'multimachine_topology nodes missing');
    my $networks = require_field($topology->{networks}, 'multimachine_topology networks missing');

    die 'multimachine_topology nodes must be an array reference'
      unless ref $nodes eq 'ARRAY';
    die 'multimachine_topology networks must be an array reference'
      unless ref $networks eq 'ARRAY';

    my (%seen_node_id, %node_by_role, %network_by_id);

    for my $node (@$nodes) {
        my $node_id = require_field($node->{id}, 'multimachine_topology node id missing');
        die "Duplicate multimachine_topology node id '$node_id'" if exists $seen_node_id{$node_id};
        $seen_node_id{$node_id} = 1;

        if (defined $node->{role} && $node->{role} ne '') {
            my $role = $node->{role};
            die "Duplicate multimachine_topology node role '$role'" if exists $node_by_role{$role};
            $node_by_role{$role} = $node;
        }

        my $interfaces = require_field($node->{interfaces}, "multimachine_topology interfaces missing for node '$node_id'");
        die "multimachine_topology interfaces for node '$node_id' must be an array reference"
          unless ref $interfaces eq 'ARRAY';
    }

    diag('multimachine_topology nodes: ' . join(', ', map { ($_->{id} // '?') . ' (' . ($_->{role} // 'no role') . ($_->{external} ? ', external' : '') . ')' } @$nodes));
    die 'multimachine_topology has no node that runs a job'
      unless grep { !$_->{external} } @$nodes;

    for my $network (@$networks) {
        my $network_id = require_field($network->{id}, 'multimachine_topology network id missing');
        die "Duplicate multimachine_topology network id '$network_id'" if exists $network_by_id{$network_id};
        $network_by_id{$network_id} = $network;
    }

    for my $node (@$nodes) {
        my $node_id = $node->{id};
        for my $interface (@{$node->{interfaces}}) {
            my $network_id = require_field($interface->{network}, "multimachine_topology interface network missing for node '$node_id'");
            die "multimachine_topology interface for node '$node_id' references unknown network '$network_id'"
              unless exists $network_by_id{$network_id};
        }
    }

    $topology->{_index} = {
        node_by_role => \%node_by_role,
        network_by_id => \%network_by_id,
    };

    return $topology;
}

=head2 get_topology

  my $topology = get_topology();

Return the C<multimachine_topology> hashref from C<get_test_suite_data()>.
The structure is validated and indexed on first access.

=cut

sub get_topology {
    my $test_data = get_test_suite_data();
    my $topology = require_field($test_data->{multimachine_topology}, 'multimachine_topology missing from test_data');

    return $topology->{_index} ? $topology : _build_topology_index($topology);
}

=head2 get_node_by_role

  my $node = get_node_by_role('peer');

Return the node hashref for the given role. Dies if no node has this
role.

=cut

sub get_node_by_role {
    my ($role) = @_;
    my $topology = get_topology();

    require_field($role, 'multimachine_topology role lookup requires a role');

    my $node = $topology->{_index}{node_by_role}{$role}
      or die "multimachine_topology node with role '$role' not found";

    return $node;
}

=head2 get_local_node

  my $node = get_local_node();

Resolve the local node using the C<ROLE> job variable. Dies if that node is
external.

=cut

sub get_local_node {
    my $role = get_required_var('ROLE');
    my $node = get_node_by_role($role);
    die "Unable to resolve local node: node with role '$role' is external"
      if $node->{external};
    return $node;
}

=head2 get_job_nodes

  my $nodes = get_job_nodes();

Return an arrayref of the nodes that run an openQA job, in topology order:
all nodes except the external ones. Use it, for example, for the number of
tasks of a barrier.

=cut

sub get_job_nodes {
    my $topology = get_topology();
    return [grep { !$_->{external} } @{$topology->{nodes}}];
}

=head2 get_peers

  my $peers = get_peers('sut');
  my $peers = get_peers($node);

Return an arrayref containing all nodes except the selected one.

=cut

sub get_peers {
    my ($node_or_role) = @_;
    my $topology = get_topology();
    my $node = ref $node_or_role eq 'HASH' ? $node_or_role : get_node_by_role($node_or_role);
    my $node_id = require_field($node->{id}, 'multimachine_topology node id missing while resolving peers');

    return [grep { $_->{id} ne $node_id } @{$topology->{nodes}}];
}

=head2 get_topology_network

  my $network = get_topology_network('lab');

Return the network hashref for the given network id. Dies if it is missing.

=cut

sub get_topology_network {
    my ($network_id) = @_;
    my $topology = get_topology();

    require_field($network_id, 'multimachine_topology network lookup requires an id');

    my $network = $topology->{_index}{network_by_id}{$network_id}
      or die "multimachine_topology network '$network_id' not found";

    return $network;
}

=head2 get_node_interface

  my $interface = get_node_interface($node, 0);

Return the interface hashref at the given index for the specified node.

=cut

sub get_node_interface {
    my ($node, $index) = @_;

    die 'multimachine_topology interface lookup requires a node hash reference'
      unless ref $node eq 'HASH';
    die 'multimachine_topology interface lookup requires an index'
      unless defined $index;

    my $interface = $node->{interfaces}[$index]
      or die "multimachine_topology interface index '$index' not found for node '$node->{id}'";

    return $interface;
}

1;
