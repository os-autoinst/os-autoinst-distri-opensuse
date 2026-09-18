# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: REST API client for VLAN configuration on the Mikrotik RouterOS switch used in kernel/storage tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::mikrotik_switch;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use HTTP::Tiny;
use JSON qw(decode_json encode_json);
use MIME::Base64 qw(encode_base64);
use Socket qw(inet_aton inet_ntoa);

our @EXPORT_OK = qw(
  get_all_vlans
  get_vlan
  add_vlan
  remove_vlan
  get_port_pvid
  set_port_pvid
);

=head2 get_all_vlans

 get_all_vlans();

Fetches every entry of the bridge VLAN table (/interface/bridge/vlan),
each containing 'bridge', 'vlan-ids', 'tagged' and 'untagged' member lists.

Dies on any non-2xx response.

=cut

sub get_all_vlans {
    my $vlans = _request('GET', 'interface/bridge/vlan');
    return @$vlans;
}

=head2 get_vlan

 get_vlan($vlan_id);

Fetches the bridge VLAN table entry for a given VLAN id, e.g. get_vlan(42).
Dies if no entry with that VLAN id exists.

Dies on any non-2xx response.

=cut

sub get_vlan {
    my ($vlan_id) = @_;
    my ($vlan) = grep { $_->{'vlan-ids'} eq $vlan_id } get_all_vlans();
    die "Mikrotik switch get_vlan($vlan_id) failed: no such VLAN\n" unless $vlan;
    return $vlan;
}

=head2 add_vlan

 add_vlan(bridge => 'bridge1', vlan_id => 42, untagged => 'ether5', tagged => 'ether1');

Adds a new entry to the bridge VLAN table. 'bridge' and 'vlan_id' are
required. 'tagged' and 'untagged' are optional comma-separated interface
lists (as accepted by RouterOS) naming the bridge member ports to attach
to the VLAN. Returns the created entry.

Dies if an entry already exists for that bridge/vlan_id — use
update_vlan() (not yet implemented) to change an existing VLAN's port
membership.

Dies on any non-2xx response.

=cut

sub add_vlan {
    my (%args) = @_;
    my $bridge = $args{bridge} // die 'add_vlan requires a bridge';
    my $vlan_id = $args{vlan_id} // die 'add_vlan requires a vlan_id';

    die "Mikrotik switch add_vlan($vlan_id) failed: a VLAN with that id already exists on bridge '$bridge'\n"
      if grep { $_->{bridge} eq $bridge && $_->{'vlan-ids'} eq $vlan_id } get_all_vlans();

    my $body = {bridge => $bridge, 'vlan-ids' => $vlan_id};
    $body->{tagged} = $args{tagged} if defined $args{tagged};
    $body->{untagged} = $args{untagged} if defined $args{untagged};

    return _request('PUT', 'interface/bridge/vlan', $body);
}

=head2 remove_vlan

 remove_vlan($vlan_id);

Removes the bridge VLAN table entry for a given VLAN id, e.g. remove_vlan(42).
Dies if no entry with that VLAN id exists.

Dies on any non-2xx response.

=cut

sub remove_vlan {
    my ($vlan_id) = @_;
    my $vlan = get_vlan($vlan_id);
    _request('DELETE', "interface/bridge/vlan/$vlan->{'.id'}");
}

=head2 get_port_pvid

 get_port_pvid($port_name);

Fetches the PVID (untagged/native VLAN id) currently configured for a
bridge port, e.g. get_port_pvid('ether5'). Dies if the port is not a
member of any bridge.

Dies on any non-2xx response.

=cut

sub get_port_pvid {
    my ($port_name) = @_;
    return _get_bridge_port($port_name)->{pvid};
}

=head2 set_port_pvid

 set_port_pvid($port_name, $vlan_id);

Sets the PVID (untagged/native VLAN id) of a bridge port, e.g.
set_port_pvid('ether5', 42). This is what makes a port an untagged member
of a VLAN. Dies if the port is not a member of any bridge.

Dies on any non-2xx response.

=cut

sub set_port_pvid {
    my ($port_name, $vlan_id) = @_;
    my $bridge_port = _get_bridge_port($port_name);
    _request('PATCH', "interface/bridge/port/$bridge_port->{'.id'}", {pvid => $vlan_id});
}

sub _get_bridge_port {
    my ($port_name) = @_;
    my $bridge_ports = _request('GET', 'interface/bridge/port', undef, {interface => $port_name});
    die "Mikrotik switch: $port_name is not a member of any bridge\n" unless @$bridge_ports;
    return $bridge_ports->[0];
}

sub _request {
    my ($method, $path, $body, $query) = @_;
    my $host = get_required_var('MIKROTIK_SWITCH_HOST');
    my $user = get_required_var('MIKROTIK_SWITCH_USER');
    my $password = get_required_var('_SECRET_MIKROTIK_SWITCH_PASSWORD');
    my $ip = inet_ntoa(inet_aton($host));

    my $url = "http://$ip/rest/$path";
    if ($query) {
        $url .= '?' . join('&', map { "$_=$query->{$_}" } sort keys %$query);
    }

    my %options = (
        headers => {
            'Content-Type' => 'application/json',
            'Authorization' => 'Basic ' . encode_base64("$user:$password", ''),
        },
    );
    $options{content} = encode_json($body) if $body;

    my $response = HTTP::Tiny->new->request($method, $url, \%options);
    die "Mikrotik switch $method $path failed: $response->{status} $response->{reason}\n" . ($response->{content} // '')
      unless $response->{success};

    return unless length($response->{content} // '');
    return decode_json($response->{content});
}

1;
