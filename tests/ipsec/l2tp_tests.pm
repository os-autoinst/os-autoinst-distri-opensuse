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

sub setup_l2tp_left {
    my ($self, $setup) = @_;

    # L2TPv3 tunnel (LEFT -> RIGHT)
    assert_script_run(
        "ip l2tp add tunnel tunnel_id 2001 peer_tunnel_id 2002 " .
          "encap ip6 local 2001:1:1:1::2 remote 2002:1:1:1::2"
    );

    assert_script_run(
        "ip l2tp add session name l2tp6 tunnel_id 2001 " .
          "session_id 3001 peer_session_id 3002"
    );

    assert_script_run("ip link set dev l2tp6 up");
    assert_script_run("ip addr add dev l2tp6 $setup->{l2tp_left_ip} peer $setup->{l2tp_right_ip}");

    barrier_wait('L2TP_SETUP_DONE');

    # L2TP connectivity tests
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

    # L2TPv3 tunnel (RIGHT -> LEFT)
    assert_script_run(
        "ip l2tp add tunnel tunnel_id 2002 peer_tunnel_id 2001 " .
          "encap ip6 local 2002:1:1:1::2 remote 2001:1:1:1::2"
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
        # L2TPv3 point-to-point tunnel addresses
        l2tp_left_ip => "fc00:1::1",
        l2tp_right_ip => "fc00:1::2",

        # Loopback behind tunnel (kernel selftest style)
        l2tp_left_lo => "fc00:101::1",
        l2tp_right_lo => "fc00:101::2",
    };

    record_info("L2TP role", $role);

    if ($role eq 'left') { $self->setup_l2tp_left($setup); }
    if ($role eq 'middle') { $self->setup_l2tp_middle($setup); }
    if ($role eq 'right') { $self->setup_l2tp_right($setup); }
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
traffic.:wq

=cut
