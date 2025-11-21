# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: L2TPv3 tests running on top of the LEFT-ROUTER-RIGHT ipsec
#          multimachine network.
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use network_utils;

sub setup_ipv4_underlay_left {
    my ($self) = @_;
    my $dev = iface();
    assert_script_run("ip addr add 10.0.0.1/24 dev $dev");
    assert_script_run("ip route add 10.0.1.0/24 via 10.0.0.254");
}

sub setup_ipv4_underlay_right {
    my ($self) = @_;
    my $dev = iface();
    assert_script_run("ip addr add 10.0.1.1/24 dev $dev");
    assert_script_run("ip route add 10.0.0.0/24 via 10.0.1.254");
}

sub setup_ipv4_underlay_middle {
    my ($self) = @_;
    my ($dev0, $dev1) = split("\n", iface(2));
    assert_script_run("ip addr add 10.0.0.254/24 dev $dev0");
    assert_script_run("ip addr add 10.0.1.254/24 dev $dev1");
}

sub setup_l2tp_left {
    my ($self, $setup) = @_;

    # L2TPv3 tunnel (LEFT -> RIGHT) using IPv4 encapsulation
    assert_script_run(
        "ip l2tp add tunnel tunnel_id 2001 peer_tunnel_id 2002 " .
          "encap ip local 10.0.0.1 remote 10.0.1.1"
    );

    assert_script_run(
        "ip l2tp add session name l2tp6 tunnel_id 2001 " .
          "session_id 3001 peer_session_id 3002"
    );

    assert_script_run("ip link set dev l2tp6 up");
    assert_script_run("ip addr add dev l2tp6 $setup->{l2tp_left_ip} peer $setup->{l2tp_right_ip}");

    barrier_wait('L2TP_SETUP_DONE');

    assert_script_run("ping6 -c 3 $setup->{l2tp_right_ip}");
    assert_script_run("ping6 -I $setup->{l2tp_left_lo} -c 3 $setup->{l2tp_right_lo}");

    barrier_wait('L2TP_TESTS_DONE');
}

sub setup_l2tp_middle {
    my ($self, $setup) = @_;

    my ($dev0, $dev1) = split("\n", iface(2));

    barrier_wait('L2TP_SETUP_DONE');

    # Observe encapsulated traffic
    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('L2TP_TESTS_DONE');
}

sub setup_l2tp_right {
    my ($self, $setup) = @_;

    # L2TPv3 tunnel (RIGHT → LEFT) using IPv4 encapsulation
    assert_script_run(
        "ip l2tp add tunnel tunnel_id 2002 peer_tunnel_id 2001 " .
          "encap ip local 10.0.1.1 remote 10.0.0.1"
    );

    assert_script_run(
        "ip l2tp add session name l2tp6 tunnel_id 2002 " .
          "session_id 3002 peer_session_id 3001"
    );

    assert_script_run("ip link set dev l2tp6 up");
    assert_script_run("ip addr add dev l2tp6 $setup->{l2tp_right_ip} peer $setup->{l2tp_left_ip}");

    barrier_wait('L2TP_SETUP_DONE');

    my $dev0 = iface();
    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('L2TP_TESTS_DONE');
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $role = get_required_var('IPSEC_SETUP');

    my $setup = {
        # L2TP P2P tunnel addresses (IPv6)
        l2tp_left_ip => "fc00:1::1",
        l2tp_right_ip => "fc00:1::2",

        # Loopback behind tunnel
        l2tp_left_lo => "fc00:101::1",
        l2tp_right_lo => "fc00:101::2",
    };

    record_info("L2TP role", $role);

    if ($role eq 'left') {
        $self->setup_ipv4_underlay_left();
        $self->setup_l2tp_left($setup);
    }

    if ($role eq 'middle') {
        $self->setup_ipv4_underlay_middle();
        $self->setup_l2tp_middle($setup);
    }

    if ($role eq 'right') {
        $self->setup_ipv4_underlay_right();
        $self->setup_l2tp_right($setup);
    }
}

1;

=head1 Description

This module performs basic L2TPv3 functional tests on top of the already
configured LEFT-ROUTER-RIGHT multimachine network used by the IPsec test
suite. The real IPv6 network and routing are prepared earlier by the
C<ipsec3hosts.pm> module; this module assumes that connectivity is already
established. Further refactor is expected, so the multimachine network shall
be abstracted to the separate module followed by specific tests like:
  - ipsec
  - l2tp
  - others

The L2TPv3 tests implemented here are intentionally minimal and closely
based on the corresponding Linux kernel selftests for L2TP. The module
creates an IPv6-encapsulated L2TPv3 tunnel between the LEFT and RIGHT
nodes, assigns point-to-point virtual tunnel addresses, configures
loopback-style addresses behind the tunnel, and verifies bidirectional
connectivity using ICMPv6. The ROUTER node passively observes tunnel
traffic.

=cut
