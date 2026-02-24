# SUSE's openQA tests
#
# Copyright 2023-2026 SUSE LLC
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
  get_ipv4_addresses
  get_ipv6_addresses
  get_net_prefix_len
  add_ipv6_addr
  add_ipv6_route
  add_ipv4_addr
  add_ipv4_route
  check_ipv6_addr
  config_ipsec
  dump_ipsec_debug
  flush_xfrm
  validate_ipsec_tcpdump
  validate_tcpdump
  capture_tcpdump
);

=head1 SYNOPSIS

Networking helper utilities for multimachine openQA tests involving
IPsec, L2TP, routing, as well as LTP NFS multi-machine tests and general
tunnel and network interfaces configuration.

=cut

=head2 get_ipv4_addresses

 my $ips_by_if = get_ipv4_addresses();

Return global IPv4 addresses grouped by interface as a hashref:

 {
   eno1 => ['10.168.192.67'],
   br0  => ['172.16.0.10', '172.16.0.11'],
 }

Interface names are keys and each value is an arrayref of IPv4 addresses
without prefix length.

=cut

sub get_ipv4_addresses {
    my $output = script_output("ip -4 -o addr show scope global");
    my %ips;

    for my $line (split(/\n/, $output)) {
        my ($ifname, $ip) = $line =~ /^\d+:\s+(\S+)\s+inet\s+(\d+\.\d+\.\d+\.\d+)\/\d+/;
        next unless $ifname && $ip;
        push @{$ips{$ifname}}, $ip;
    }

    return \%ips;
}

=head2 get_ipv6_addresses

 my $ips_by_if = get_ipv6_addresses();

Return global IPv6 addresses grouped by interface as a hashref:

 {
   eno1 => ['2a07:de40:a102:5::1'],
   br0  => ['2001:db8::10', '2001:db8::11'],
 }

Interface names are keys and each value is an arrayref of IPv6 addresses
without prefix length.

=cut

sub get_ipv6_addresses {
    my $output = script_output("ip -6 -o addr show scope global");
    my %ips;

    for my $line (split(/\n/, $output)) {
        my ($ifname, $ip) = $line =~ /^\d+:\s+(\S+)\s+inet6\s+([0-9a-fA-F:.]+)\/\d+/;
        next unless $ifname && $ip;
        push @{$ips{$ifname}}, $ip;
    }

    return \%ips;
}

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

=head2 validate_ipsec_tcpdump

 validate_ipsec_tcpdump($dump, $setup, $devname);

Validate that tcpdump output on a given device contains ESP packets
with the expected SPI.

=cut

sub validate_ipsec_tcpdump {
    my ($dump) = @_;

    record_info("Validating tcpdump");

    # expected SPI from Kernel::net_tests::build_ipsec_params defaults
    my $expected_spi = "0x26c44388";

    my $found_spi = ($dump =~ /ESP\(spi=$expected_spi/i);

    unless ($found_spi) {
        record_info("FAIL", "Missing expected ESP SPI $expected_spi in tcpdump",
            result => 'fail');
    }
    record_info('tcpdump', $dump);
}

=head2 validate_tcpdump

 validate_tcpdump(
     dump  => $dump,
     check => 'esp' | ['esp','pmtud'],
     spi   => '0x12345678',
     mtu   => 1300,
     dev   => 'ens4'
 );

Validate tcpdump output for expected IPsec traffic patterns.

Supported checks:

- C<esp>:   Verify that ESP packets are present and match the expected SPI.
- C<pmtud>: Verify that ICMPv6 Packet Too Big messages appear with the expected MTU.

If multiple checks are requested, all of them must be found in the dump.
Missing patterns cause the test to fail via C<record_info(..., result => 'fail')>.

=cut

sub validate_tcpdump {
    my (%args) = @_;

    my $dump = $args{dump};
    my $checks = $args{check};    # arrayref ['esp', 'pmtud']
    my $expected_spi = $args{spi};    # expected SPI
    my $mtu = $args{mtu};    # expected MTU
    my $dev = $args{dev};    # optional

    # Normalize: allow single scalar check => 'esp'
    $checks = [$checks] unless ref $checks eq 'ARRAY';

    record_info("Validating tcpdump on $dev (checks: " . join(',', @$checks) . ")");

    foreach my $check (@$checks) {

        if ($check eq 'esp') {
            my $found_spi = ($dump =~ /ESP\(spi=$expected_spi/i);

            unless ($found_spi) {
                record_info("FAIL", "Missing expected ESP SPI $expected_spi in tcpdump",
                    result => 'fail');
            }
        }

        elsif ($check eq 'pmtud') {
            unless ($dump =~ /ICMP6.*packet too big.*mtu\s*$mtu/i) {
                record_info("FAIL", "Missing ICMPv6 Packet Too Big (mtu=$mtu)", result => 'fail');
            }
        }

        else {
            record_info("FAIL", "Unknown tcpdump check '$check'", result => 'fail');
        }
    }

    record_info("tcpdump", $dump);
}

=head2 capture_tcpdump

 capture_tcpdump($dev);
 capture_tcpdump($dev, $timeout);

Run C<tcpdump> on the given network interface C<$dev> for a limited duration
(using the C<timeout> command) and return the captured packet output as a
string.

Arguments:

=over 2

=item *
C<$dev> - Network interface to capture on (e.g. C<eth0>).

=item *
C<$timeout> - Optional duration in seconds to run tcpdump (defaults to 10).

=back

The function always uses C<tcpdump -n> (numeric output) and sets
C<proceed_on_failure => 1> so that failed or empty captures do not abort
the test module.

=cut

sub capture_tcpdump {
    my ($dev, $timeout) = @_;
    $timeout //= 10;

    return script_output(
        "timeout $timeout tcpdump -i $dev -n",
        timeout => $timeout + 2,
        proceed_on_failure => 1
    );
}

1;
