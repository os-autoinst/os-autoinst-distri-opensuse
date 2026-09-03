# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: REST API client for the Brocade FC switch used in kernel/storage tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::brocade_switch;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use HTTP::Tiny;
use JSON qw(decode_json);
use MIME::Base64 qw(encode_base64);
use Socket qw(inet_aton inet_ntoa);

our @EXPORT_OK = qw(
  login
  logout
  get_port
  get_all_ports
  get_all_enabled_ports
  enable_port
  disable_port
);

=head2 login

 login();

Logs in to the Brocade FC switch REST API. Host, user and password are read
from the FC_SWITCH_BROCADE_HOST, FC_SWITCH_BROCADE_USER and
_SECRET_FC_SWITCH_BROCADE_PASSWORD job settings. Returns the session
authorization token (e.g. "Custom_Basic ...") to pass as the Authorization
header on subsequent requests.

Dies on any non-2xx response or a missing token in the response.

=cut

sub login {
    my $host = get_required_var('FC_SWITCH_BROCADE_HOST');
    my $user = get_required_var('FC_SWITCH_BROCADE_USER');
    my $password = get_required_var('_SECRET_FC_SWITCH_BROCADE_PASSWORD');
    my $ip = inet_ntoa(inet_aton($host));

    my $response = HTTP::Tiny->new->request('POST', "http://$ip/rest/login", {
            headers => {
                'Accept' => 'application/yang-data+json',
                'Content-Type' => 'application/yang-data+json',
                'Authorization' => 'Basic ' . encode_base64("$user:$password", ''),
            },
    });
    die "Brocade switch login failed: $response->{status} $response->{reason}"
      unless $response->{success};

    my $token = $response->{headers}{authorization};
    die 'Brocade switch login succeeded but no session token was returned' unless $token;
    return $token;
}

=head2 logout

 logout($token);

Closes the REST API session identified by $token, as returned by login().

Dies on any non-2xx response.

=cut

sub logout {
    my ($token) = @_;
    my $host = get_required_var('FC_SWITCH_BROCADE_HOST');
    my $ip = inet_ntoa(inet_aton($host));

    my $response = HTTP::Tiny->new->request('POST', "http://$ip/rest/logout", {
            headers => {
                'Authorization' => $token,
            },
    });
    die "Brocade switch logout failed: $response->{status} $response->{reason}"
      unless $response->{success};
}

=head2 get_port

 get_port($token, $port_name);

Fetches the current state of a Fibre Channel port, e.g. get_port($token, '0/1').
Returns the decoded "fibrechannel" hashref from the switch's response, e.g.
containing 'is-enabled-state', 'physical-state', 'name' and other port fields.

Dies on any non-2xx response.

=cut

sub get_port {
    my ($token, $port_name) = @_;
    my $host = get_required_var('FC_SWITCH_BROCADE_HOST');
    my $ip = inet_ntoa(inet_aton($host));
    (my $encoded_port_name = $port_name) =~ s{/}{%2f}g;

    my $response = HTTP::Tiny->new->request('GET',
        "http://$ip/rest/running/brocade-interface/fibrechannel/name/$encoded_port_name", {
            headers => {
                'Accept' => 'application/yang-data+json',
                'Authorization' => $token,
            },
        });
    die "Brocade switch get_port($port_name) failed: $response->{status} $response->{reason}"
      unless $response->{success};

    return decode_json($response->{content})->{Response}{fibrechannel};
}

=head2 get_all_ports

 get_all_ports($token);

Fetches the current state of every Fibre Channel port on the switch.
Returns an array of the same per-port hashrefs as get_port().

Dies on any non-2xx response.

=cut

sub get_all_ports {
    my ($token) = @_;
    my $host = get_required_var('FC_SWITCH_BROCADE_HOST');
    my $ip = inet_ntoa(inet_aton($host));

    my $response = HTTP::Tiny->new->request('GET',
        "http://$ip/rest/running/brocade-interface/fibrechannel", {
            headers => {
                'Accept' => 'application/yang-data+json',
                'Authorization' => $token,
            },
        });
    die "Brocade switch get_all_ports() failed: $response->{status} $response->{reason}"
      unless $response->{success};

    my $ports = decode_json($response->{content})->{Response}{fibrechannel};
    # normalize: a single-port result may come back as a hashref rather than
    # an arrayref of one, depending on FOS version
    return ref($ports) eq 'ARRAY' ? @$ports : ($ports);
}

=head2 get_all_enabled_ports

 get_all_enabled_ports($token);

Fetches every Fibre Channel port that is currently enabled
(is-enabled-state true), as returned by get_all_ports().

Dies on any non-2xx response.

=cut

sub get_all_enabled_ports {
    my ($token) = @_;
    return grep { $_->{'is-enabled-state'} } get_all_ports($token);
}

=head2 enable_port

 enable_port($token, $port_name);

Enables a Fibre Channel port, e.g. enable_port($token, '0/1').

Dies on any non-2xx response.

=cut

sub enable_port {
    my ($token, $port_name) = @_;
    _set_port_state($token, $port_name, 'true');
}

=head2 disable_port

 disable_port($token, $port_name);

Disables a Fibre Channel port, e.g. disable_port($token, '0/1').

Dies on any non-2xx response.

=cut

sub disable_port {
    my ($token, $port_name) = @_;
    _set_port_state($token, $port_name, 'false');
}

sub _set_port_state {
    my ($token, $port_name, $state) = @_;
    my $host = get_required_var('FC_SWITCH_BROCADE_HOST');
    my $ip = inet_ntoa(inet_aton($host));
    (my $encoded_port_name = $port_name) =~ s{/}{%2f}g;

    my $response = HTTP::Tiny->new->request('PATCH',
        "http://$ip/rest/running/brocade-interface/fibrechannel/name/$encoded_port_name/is-enabled-state/$state", {
            headers => {
                'Authorization' => $token,
            },
        });
    die "Brocade switch set_port_state($port_name, $state) failed: $response->{status} $response->{reason}"
      unless $response->{success};
}

1;
