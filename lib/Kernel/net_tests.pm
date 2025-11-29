# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Generic network base module for multimachine tests (IPsec, L2TP, etc.)
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::net_tests;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Architectures;
use lockapi;
use Utils::Logging;
use network_utils;
use mm_network;

our @EXPORT_OK = qw(
  get_net_prefix_len
  add_ipv6_addr
  add_ipv6_route
  add_ipv4_addr
  add_ipv4_route
  check_ipv6_addr
  config_ipsec
  dump_ipsec_debug
  flush_xfrm
);

=head1 SYNOPSIS

Networking helper utilities for multimachine openQA tests involving
IPsec, L2TP, routing, and general tunnel configuration.

=cut


=head2 get_net_prefix_len

 get_net_prefix_len(net => '2001:db8::/64');

Return the prefix length extracted from a C<address/prefix> string.
Returns C<undef> if no prefix is present.

=cut

sub get_net_prefix_len {
    my (%args) = @_;
    my ($len) = $args{net} =~ /\/(\d+)/;
    return $len;
}

=head2 add_ipv6_addr

 add_ipv6_addr(ip => '2001:db8::1', dev => 'eth0', plen => 64);

Assign an IPv6 address with prefix length to an interface. Defaults:
- C<dev>: result of C<iface()>
- C<plen>: 64

=cut

sub add_ipv6_addr {
    my (%args) = @_;
    $args{dev} ||= iface();
    $args{plen} ||= 64;
    $args{ip} = $args{ip} . "/" . $args{plen};
    assert_script_run("ip -6 addr add $args{ip} dev $args{dev}");
}

=head2 add_ipv6_route

 add_ipv6_route(dst => '2001:db8:2::/64', via => '2001:db8::1');

Add an IPv6 route using C<ip -6 route add>.

=cut

sub add_ipv6_route {
    my (%args) = @_;
    assert_script_run("ip -6 route add $args{dst} via $args{via}");
}

=head2 add_ipv4_addr

 add_ipv4_addr(ip => '192.0.2.10', dev => 'eth0', plen => 24);

Assign an IPv4 address with prefix length to an interface. Defaults:
- C<dev>: result of C<iface()>
- C<plen>: 24

=cut

sub add_ipv4_addr {
    my (%args) = @_;
    $args{dev} ||= iface();
    $args{plen} ||= 24;
    my $cidr = "$args{ip}/$args{plen}";
    assert_script_run("ip addr add $cidr dev $args{dev}");
}


=head2 add_ipv4_route

 add_ipv4_route(dst => '192.0.2.0/24', via => '192.0.2.1');

Add an IPv4 route using C<ip route add>.

=cut

sub add_ipv4_route {
    my (%args) = @_;
    assert_script_run("ip route add $args{dst} via $args{via}");
}

=head2 check_ipv6_addr

 check_ipv6_addr();

Wait until the system obtains a usable IPv6 address. The function checks
for:
- presence of a link-local C<fe80::> address
- address no longer in C<tentative> state

Waits up to 50 seconds (10 attempts * 5 seconds).

=cut

sub check_ipv6_addr {
    my $errors = 0;
    my $tries = 10;
    my $no_ip = 1;
    my $output = '';
    while ($tries > 0 && $no_ip) {
        $no_ip = 0;
        $output = script_output('ip a');
        if (($output !~ /inet6.*fe80/) || ($output =~ /tentative/)) {
            record_info('Waiting for IPv6 ready, still tentative state');
            $no_ip = 1;
        }
        $tries -= 1;
        sleep(5);
    }
}

=head2 flush_xfrm

 flush_xfrm();

Flush all existing XFRM state and policy entries. Useful when resetting
IPsec configuration between test phases.

=cut

sub flush_xfrm {
    assert_script_run("ip xfrm state flush && ip xfrm policy flush");
}

=head2 build_ipsec_params

 my %params = build_ipsec_params(
     aead  => q('rfc4309(ccm(aes))'),
     replay => 96,
 );

Return a hash of IPsec/XFRM configuration parameters (crypto algorithm,
SPI, keys, replay tag size, etc.). Test authors may override any field.

=cut

sub build_ipsec_params {
    my (%args) = @_;

    return (
        spi => $args{spi} // "0x26c44388",
        reqid => $args{reqid} // "0x26c44388",
        key => $args{key} // "0x6f887514ca6eccb1d273366f70b21a91aa2a3421",
        mode => $args{mode} // "tunnel",
        aead => $args{aead} // q('rfc4106(gcm(aes))'),
        proto => "esp",
        replay => $args{replay} // 128,
        flush => $args{flush} // 1,
    );
}

=head2 install_ipsec_state

 install_ipsec_state(
     %params,
     local_ip  => '2001:db8::1',
     remote_ip => '2001:db8::2',
 );

Install ESP outbound and inbound Security Associations (SAs)
using the provided IPsec parameters and tunnel endpoint IPs.

=cut

sub install_ipsec_state {
    my (%args) = @_;

    # Outbound (local -> remote)
    assert_script_run(
        "ip xfrm state add src $args{local_ip} dst $args{remote_ip} " .
          "proto $args{proto} spi $args{spi} reqid $args{reqid} " .
          "mode $args{mode} aead $args{aead} $args{key} $args{replay}"
    );

    # Inbound (remote -> local)
    assert_script_run(
        "ip xfrm state add src $args{remote_ip} dst $args{local_ip} " .
          "proto $args{proto} spi $args{spi} reqid $args{reqid} " .
          "mode $args{mode} aead $args{aead} $args{key} $args{replay}"
    );
}

=head2 install_ipsec_policies

 install_ipsec_policies(
     %params,
     local_ip       => '2001:db8::1',
     remote_ip      => '2001:db8::2',
     new_local_net  => '2001:db8:100::/64',
     new_remote_net => '2001:db8:200::/64',
 );

Install inbound and outbound XFRM policies that link traffic selectors
(new_local_net -> new_remote_net) to the IPsec state installed earlier.

=cut

sub install_ipsec_policies {
    my (%args) = @_;

    # Outbound policy (local -> remote)
    assert_script_run(
        "ip xfrm policy add src $args{new_local_net} dst $args{new_remote_net} " .
          "dir out tmpl src $args{local_ip} dst $args{remote_ip} " .
          "proto $args{proto} reqid $args{reqid} mode $args{mode}"
    );

    # Inbound policy (remote -> local)
    assert_script_run(
        "ip xfrm policy add src $args{new_remote_net} dst $args{new_local_net} " .
          "dir in tmpl src $args{remote_ip} dst $args{local_ip} " .
          "proto $args{proto} reqid $args{reqid} mode $args{mode}"
    );
}


sub config_ipsec {
    my (%args) = @_;

    # Flush if required
    flush_xfrm();

    # Extract IPsec parameters (already combined from %params and overrides)
    my %p = build_ipsec_params(%args);

    # Install both directions of SA
    install_ipsec_state(
        %p,
        local_ip => $args{local_ip},
        remote_ip => $args{remote_ip},
    );

    # Install selectors/policies
    install_ipsec_policies(
        %p,
        local_ip => $args{local_ip},
        remote_ip => $args{remote_ip},
        new_local_net => $args{new_local_net},
        new_remote_net => $args{new_remote_net},
    );
}

=head2 dump_ipsec_debug

 dump_ipsec_debug();

Record detailed debugging information about IPsec state, policy, and
IPv6 routing. Useful for post-failure diagnostics.

=cut

sub dump_ipsec_debug {
    my $state = script_output('ip -d xfrm state', proceed_on_failure => 1);
    my $policy = script_output('ip -d xfrm policy', proceed_on_failure => 1);
    my $routes = script_output('ip -6 route', proceed_on_failure => 1);

    record_info('IPsec state', $state);
    record_info('IPsec policy', $policy);
    record_info('IPv6 routes', $routes);
}

1;
