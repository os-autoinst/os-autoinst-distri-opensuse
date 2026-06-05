# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Basic setup and functional L2TPv3 connectivity test.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package l2tp3hosts;
use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use network_utils;
use Kernel::net_tests qw(
  add_ipv4_addr
  add_ipv4_route
);
use Kernel::multimachine_topology qw(
  get_topology
  get_node_by_role
  get_interface
  require_field
);

sub get_l2tp_3hosts_setup {
    my $topology = get_topology();
    my $l2tp = require_field($topology->{l2tp}, 'multimachine_topology l2tp section missing');
    my $left = get_node_by_role('left');
    my $middle = get_node_by_role('middle');
    my $right = get_node_by_role('right');

    my $left_if = get_interface($left, 0);
    my $right_if = get_interface($right, 0);
    my $middle_if_01 = get_interface($middle, 0);
    my $middle_if_02 = get_interface($middle, 1);

    return {
        left_ip4 => require_field($left_if->{ipv4}, 'left IPv4 missing from multimachine_topology'),
        middle_ip4_01 => require_field($middle_if_01->{ipv4}, 'middle interface 0 IPv4 missing from multimachine_topology'),
        middle_ip4_02 => require_field($middle_if_02->{ipv4}, 'middle interface 1 IPv4 missing from multimachine_topology'),
        right_ip4 => require_field($right_if->{ipv4}, 'right IPv4 missing from multimachine_topology'),
        l2tp4_left => require_field($l2tp->{pseudowire}{left}, 'left L2TP pseudowire IPv4 missing from multimachine_topology'),
        l2tp4_right => require_field($l2tp->{pseudowire}{right}, 'right L2TP pseudowire IPv4 missing from multimachine_topology'),
        lo_v4_left => require_field($l2tp->{loopback}{left}, 'left L2TP loopback IPv4 missing from multimachine_topology'),
        lo_v4_right => require_field($l2tp->{loopback}{right}, 'right L2TP loopback IPv4 missing from multimachine_topology'),
    };
}

sub run_left {
    my ($self, $setup) = @_;
    my $dev = iface(0);

    add_ipv4_addr(ip => $setup->{left_ip4}, dev => $dev);
    add_ipv4_route(
        dst => "$setup->{right_ip4}/32",
        via => $setup->{middle_ip4_01}
    );

    script_retry("ping -c 1 $setup->{middle_ip4_01}", retry => 5);

    # Create the L2TPv3 tunnel
    assert_script_run(
        "ip l2tp add tunnel tunnel_id 2001 peer_tunnel_id 2002 " .
          "encap ip local $setup->{left_ip4} remote $setup->{right_ip4}"
    );

    # Create the L2TPv3 session
    assert_script_run(
        "ip l2tp add session name l2tp4 tunnel_id 2001 " .
          "session_id 3001 peer_session_id 3002"
    );

    assert_script_run("ip link set l2tp4 up");

    assert_script_run(
        "ip addr add $setup->{l2tp4_left} peer $setup->{l2tp4_right} dev l2tp4"
    );

    # Loopback endpoints for test
    add_ipv4_addr(ip => $setup->{lo_v4_left}, plen => 32, dev => 'lo');

    # Route the right-side loopback via the L2TP tunnel
    add_ipv4_route(
        dst => "$setup->{lo_v4_right}/32",
        via => $setup->{l2tp4_right}
    );

    barrier_wait('L2TP_SETUP_DONE');

    assert_script_run("ping -c 4 $setup->{l2tp4_right}");
    assert_script_run("ping -c 4 $setup->{lo_v4_right}");

    barrier_wait('L2TP_TESTS_DONE');
}

sub run_middle {
    my ($self, $setup) = @_;
    my $dev0 = iface(0);
    my $dev1 = iface(1);

    # Router enable forwarding
    assert_script_run("sysctl -w net.ipv4.ip_forward=1");
    assert_script_run("sysctl -w net.ipv4.conf.all.rp_filter=0");
    assert_script_run("sysctl -w net.ipv4.conf.default.rp_filter=0");

    add_ipv4_addr(ip => $setup->{middle_ip4_01}, dev => $dev0);
    add_ipv4_addr(ip => $setup->{middle_ip4_02}, dev => $dev1);

    assert_script_run("ip link set $dev0 up");
    assert_script_run("ip link set $dev1 up");

    script_retry("ping -c 1 $setup->{left_ip4}", retry => 5);
    script_retry("ping -c 1 $setup->{right_ip4}", retry => 5);

    barrier_wait('L2TP_SETUP_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('L2TP_TESTS_DONE');
}

sub run_right {
    my ($self, $setup) = @_;
    my $dev = iface(0);

    add_ipv4_addr(ip => $setup->{right_ip4}, dev => $dev);
    add_ipv4_route(
        dst => "$setup->{left_ip4}/32",
        via => $setup->{middle_ip4_02}
    );

    script_retry("ping -c 1 $setup->{middle_ip4_02}", retry => 5);

    # Create the L2TPv3 tunnel
    assert_script_run(
        "ip l2tp add tunnel tunnel_id 2002 peer_tunnel_id 2001 " .
          "encap ip local $setup->{right_ip4} remote $setup->{left_ip4}"
    );

    # Create the L2TPv3 session
    assert_script_run(
        "ip l2tp add session name l2tp4 tunnel_id 2002 " .
          "session_id 3002 peer_session_id 3001"
    );

    assert_script_run("ip link set l2tp4 up");

    assert_script_run(
        "ip addr add $setup->{l2tp4_right} peer $setup->{l2tp4_left} dev l2tp4"
    );

    # Loopback endpoints for test
    add_ipv4_addr(ip => $setup->{lo_v4_right}, plen => 32, dev => 'lo');

    # Route the left-side loopback via the L2TP tunnel
    add_ipv4_route(
        dst => "$setup->{lo_v4_left}/32",
        via => $setup->{l2tp4_left}
    );


    barrier_wait('L2TP_SETUP_DONE');

    my $dev0 = iface(0);
    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('L2TP_TESTS_DONE');
}

sub run {
    my ($self) = @_;
    my $role = get_required_var('ROLE');
    select_serial_terminal;

    my $setup = get_l2tp_3hosts_setup();

    record_info('ROLE', $role);

    if ($role eq 'left') { $self->run_left($setup); }
    elsif ($role eq 'middle') { $self->run_middle($setup); }
    elsif ($role eq 'right') { $self->run_right($setup); }
    else { die "Unknown ROLE '$role': expected 'left', 'middle', or 'right'"; }
}

1;

=head1 Description

l2tp3hosts - Multimachine IPv4 L2TPv3 functional test validating tunnel
creation, pseudowire session setup, routing, and end-to-end connectivity
across a three-host topology.

This module implements a minimal L2TPv3 pseudowire scenario inspired by the
Linux kernel selftests (net/l2tp).

Network topology used in this test:

   LEFT HOST  <---------->  MIDDLE ROUTER   <----------->  RIGHT HOST
    10.1.1.1                  10.1.1.2                        10.1.2.1
                              10.1.2.2

   L2TPv3 tunnel:
     LEFT l2tp4: 172.16.1.1  <=============>  172.16.1.2 :l2tp4 RIGHT

   Loopback endpoints routed through L2TP:
     LEFT lo:  172.16.101.1  <=============>  172.16.101.2 :lo RIGHT


Traffic to these loopback endpoints is routed through the L2TPv3 pseudowire,
verifying proper tunnel forwarding, addressing, and encapsulation.

=cut
