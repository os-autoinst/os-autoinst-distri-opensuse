# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Multimachine IPsec test verifying connectivity, routing,
#          tunnel/transport mode operation, and PMTUD across a
#          three-host IPv6 topology.
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

package ipsec3hosts;
use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use network_utils;
use Kernel::net_tests qw(
  add_ipv6_addr
  add_ipv6_route
  get_net_prefix_len
  check_ipv6_addr
  config_ipsec
  dump_ipsec_debug
  validate_tcpdump
  capture_tcpdump
);

sub run_left {
    my ($self, $setup) = @_;

    # hash for the ipsec config
    my $ipsec_setting_left = {
        local_ip => $setup->{left_ip},
        remote_ip => $setup->{right_ip},
        new_local_net => $setup->{left_net},
        new_remote_net => $setup->{right_net},
    };

    add_ipv6_addr(
        ip => $setup->{left_ip},
        plen => get_net_prefix_len(net => $setup->{left_net})
    );
    check_ipv6_addr();

    barrier_wait('IPSEC_IP_SETUP_DONE');

    # first traffic test/check. At this point it should be possible to
    # ping the middle. So ping the middle router interface on the same subnet
    record_info("Test01: connectivity", "Ping router/middle host");
    script_retry("ping -c 1 $setup->{middle_ip_01}", retry => 5);
    record_info('IP NEIGHBOR', script_output('ip neighbor show'));

    add_ipv6_route(
        dst => $setup->{right_ip},
        via => $setup->{middle_ip_01}
    );

    barrier_wait('IPSEC_ROUTE_SETUP_DONE');

    record_info('IP ADDRESS', script_output('ip a'));
    record_info('IP ROUTE', script_output('ip -6 route'));

    # second test/check. Routs added, at this point it should be possible to
    # ping the right and the net interface in the middle from the other subnet
    record_info("Test02: connectivity", "Ping router/middle host and right host");
    script_retry("ping -c 1 $setup->{middle_ip_01}", retry => 5);
    script_retry("ping -c 1 $setup->{right_ip}", retry => 5);

    barrier_wait('IPSEC_ROUTE_SETUP_CHECK_DONE');

    # apply ipsec configs
    config_ipsec(%$ipsec_setting_left);

    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');
    dump_ipsec_debug();

    # third tests using ipsec. Basic check to see if it's possible to
    # ping the right using ipsec encryption. Default MTU-size packages as well
    # as 1300 MTU size
    record_info("Test03: mode tunnel", "Ping over ipsec");
    assert_script_run("ping -c 8 $setup->{right_ip}");
    assert_script_run("ping6 -s 1300 -c 8 $setup->{right_ip}");

    barrier_wait('IPSEC_SET_MTU_DONE');

    # fourth test/check. Here the middle/router lowers the MTU to 1300. The left host
    # still sends packets using the default MTU, so oversized packets should trigger
    # Path MTU Discovery (PMTUD). The test verifies that ICMPv6 Packet-Too-Big
    # messages are handled correctly and the sender adjusts to the lower MTU
    record_info("Test04: MTU", "MTU size in the middle decreased");
    assert_script_run("ping6 -c 8 $setup->{right_ip}");
    assert_script_run("ping6 -s 1300 -c 20 $setup->{right_ip}");

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');

    # mode changed from tunnel to transport
    config_ipsec(%$ipsec_setting_left, mode => 'transport');

    barrier_wait('IPSEC_TRANSPORT_MODE_SETUP_DONE');
    #dump the xfrm to see if correct mode is there
    dump_ipsec_debug();

    # fifth test. Corresponding test as the 04 however the transport mode
    # is being used
    record_info("Test05: mode transport", "Use transport mode of ipsec");
    assert_script_run("ping6 -c 8 $setup->{right_ip}");
    assert_script_run("ping6 -s 1300 -c 8 $setup->{right_ip}");

    barrier_wait('IPSEC_TRANSPORT_MODE_CHECK_DONE');
}

sub run_middle {
    my ($self, $setup) = @_;

    my ($dev0, $dev1) = split("\n", iface(2));

    assert_script_run("sysctl net.ipv6.conf.all.forwarding=1");
    assert_script_run("ip link set $dev0 up");
    assert_script_run("ip link set $dev1 up");

    add_ipv6_addr(
        ip => $setup->{middle_ip_01},
        dev => $dev0,
        plen => get_net_prefix_len(net => $setup->{middle_net_01})
    );

    add_ipv6_addr(
        ip => $setup->{middle_ip_02},
        dev => $dev1,
        plen => get_net_prefix_len(net => $setup->{middle_net_02})
    );

    check_ipv6_addr();

    # basic connectivity checks. At this point it should be possible
    # to ping left and right from the the middle
    script_retry("ping -c 1 $setup->{left_ip}", retry => 5);
    script_retry("ping -c 1 $setup->{right_ip}", retry => 5);

    record_info('IP NEIGHBOR', script_output('ip neighbor show'));

    barrier_wait('IPSEC_IP_SETUP_DONE');
    barrier_wait('IPSEC_ROUTE_SETUP_DONE');

    record_info('IP ADDRESS', script_output('ip a'));
    record_info('IP ROUTE', script_output('ip -6 route'));

    barrier_wait('IPSEC_ROUTE_SETUP_CHECK_DONE');
    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');

    # Test03
    record_info("Test03: mode tunnel", "Ping over ipsec");
    # We expect here (at least):
    # ESP
    # spi 0x26c44388

    # validate first net device
    my $dump;
    $dump = capture_tcpdump($dev0);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => "0x26c44388", dev => $dev0,);

    # validate second net device
    $dump = capture_tcpdump($dev1);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => "0x26c44388", dev => $dev1,);

    assert_script_run("ip link set mtu 1300 dev $dev1");

    barrier_wait('IPSEC_SET_MTU_DONE');

    # Test04
    record_info("Test04: MTU", "MTU size in the middle decreased");
    # We expect here (at least):
    # ESP
    # spi 0x26c44388
    # packet too big
    # ICMP6, Packet Too Big

    # validate first net device; here we check for pmtud
    $dump = capture_tcpdump($dev0, 15);
    validate_tcpdump(dump => $dump, check => ['esp', 'pmtud'], spi => "0x26c44388", mtu => 1300, dev => $dev0,);

    # validate second net device; here pmtud won't be present
    $dump = capture_tcpdump($dev1);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => "0x26c44388", dev => $dev1,);

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');
    barrier_wait('IPSEC_TRANSPORT_MODE_SETUP_DONE');

    # TODO:
    # The same IPs are currently used as both tunnel endpoints and
    # communicating hosts. Because the outer IPv6 header is identical
    # in both modes, tcpdump cannot distinguish tunnel from transport
    # mode. To validate this properly, the topology must use:
    #
    #   - host IPs inside each subnet (e.g. ::A, ::B)
    #   - tunnel endpoint IPs used only for XFRM src/dst
    #
    # With subnet-based selectors, tunnel-mode packets would originate
    # from the tunnel endpoints, while transport-mode packets would come
    # from host IPs. Only then can tcpdump validation differentiate modes.

    # Test05
    record_info("Test05: mode transport", "Use transport mode of ipsec");
    # We expect here (for now):
    # ESP
    # spi 0x26c44388

    # validate first net device
    $dump = capture_tcpdump($dev0);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => "0x26c44388", dev => $dev0,);

    # validate second net device
    $dump = capture_tcpdump($dev1);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => "0x26c44388", dev => $dev1,);

    barrier_wait('IPSEC_TRANSPORT_MODE_CHECK_DONE');
}

sub run_right {
    my ($self, $setup) = @_;

    # hash for the ipsec config
    my $ipsec_setting_right = {
        local_ip => $setup->{right_ip},
        remote_ip => $setup->{left_ip},
        new_local_net => $setup->{right_net},
        new_remote_net => $setup->{left_net},
    };

    my $dev0 = iface();

    add_ipv6_addr(
        ip => $setup->{right_ip},
        plen => get_net_prefix_len(net => $setup->{right_net})
    );

    check_ipv6_addr();
    barrier_wait('IPSEC_IP_SETUP_DONE');

    # basic connectivity check. Here it should be possible to ping
    # middle, the network interface from the same subnet as the right one
    script_retry("ping -c 1 $setup->{middle_ip_02}", retry => 5);

    record_info('IP NEIGHBOR', script_output('ip neighbor show'));

    add_ipv6_route(
        dst => $setup->{left_ip},
        via => $setup->{middle_ip_02}
    );

    barrier_wait('IPSEC_ROUTE_SETUP_DONE');

    record_info('IP ADDRESS', script_output('ip a'));
    record_info('IP ROUTE', script_output('ip -6 route'));

    # basic connectivity check. Routes are set, so it should be possible
    # to ping middle network interface from the other subnet as well as
    # the left one
    script_retry("ping -c 1 $setup->{middle_ip_02}", retry => 5);
    script_retry("ping -c 1 $setup->{left_ip}", retry => 5);

    barrier_wait('IPSEC_ROUTE_SETUP_CHECK_DONE');

    # applying ipsec config
    config_ipsec(%$ipsec_setting_right);

    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('IPSEC_SET_MTU_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');

    # switching the ipsec mode to transport
    config_ipsec(%$ipsec_setting_right, mode => 'transport');

    barrier_wait('IPSEC_TRANSPORT_MODE_SETUP_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('IPSEC_TRANSPORT_MODE_CHECK_DONE');
}

sub run {
    my ($self) = @_;

    my $role = get_var('IPSEC_SETUP');
    select_serial_terminal;

    my $setup = {
        left_ip => "2001:1:1:1::2",
        right_ip => "2002:1:1:1::2",
        left_net => "2001:1:1:1::/64",
        right_net => "2002:1:1:1::/64",
        middle_ip_01 => "2001:1:1:1::1",
        middle_ip_02 => "2002:1:1:1::1",
        middle_net_01 => "2001:1:1:1::/64",
        middle_net_02 => "2002:1:1:1::/64",
    };

    record_info('IPSEC_SETUP', $role);

    record_info('nmcli connect status', script_output('nmcli c'));
    record_info('nmcli device status', script_output('nmcli device s'));
    record_info('ip status', script_output('ip a'));
    record_info('INTF STATUS', script_output('ip -s link show', proceed_on_failure => 1));

    if ($role eq 'left') { $self->run_left($setup); }
    if ($role eq 'middle') { $self->run_middle($setup); }
    if ($role eq 'right') { $self->run_right($setup); }
}

sub pre_run_hook {
    my ($self) = @_;
    mutex_wait 'support_server_ready';
    select_serial_terminal;
    record_info('/etc/machine-id', script_output('cat /etc/machine-id'));
    record_info('nmcli connect status', script_output('nmcli c'));
    record_info('nmcli device status', script_output('nmcli device s'));
    record_info('ip status', script_output('ip a'));
    quit_packagekit();
    ensure_service_disabled('apparmor');
    ensure_service_disabled($self->firewall);
    set_hostname(get_var('HOSTNAME', 'susetest'));

    zypper_call('install tcpdump');
}

sub post_fail_hook {
    my ($self) = @_;
    export_logs();
    record_info('INTF STATUS', script_output('ip -s link show', proceed_on_failure => 1));
}

1;

=head1 Description

ipsec3hosts - Multimachine IPv6 IPsec test validating routing, ESP traffic,
PMTUD, and tunnel/transport mode operation across a three-host topology.

This module implements a full three-host IPv6 IPsec test environment:

    LEFT HOST  <---------->  MIDDLE/ROUTER  <----------->  RIGHT HOST

   2001:1:1:1::2            2001:1:1:1::1                 2002:1:1:1::2
                            2002:1:1:1::1

It is scheduled as part of a multimachine openQA scenario. The test configures
IPv6 networking, routing, and IPsec on all three hosts and then exercises
encrypted communication in both tunnel and transport modes.

The overall test flow and thus specific tests are:

Test01:
    Basic L2/L3 connectivity. Each endpoint must be able to ping the middle
    router on its local subnet. Verifies addressing, link status, and neighbor
    discovery.

Test02:
    Verify routing configuration. After static routes are added, both endpoints
    must reach each other through the middle router (no IPsec yet). Ensures
    IPv6 routing is functional.

Test03:
    IPsec tunnel mode enabled. Traffic from left to right must be encapsulated
    as ESP. tcpdump on the middle router must show ESP packets on both
    interfaces. Basic encrypted communication and MTU-sized packets are tested.

Test04:
    PMTUD with tunnel mode. The middle router reduces MTU to 1300 on one link.
    Oversized packets must trigger ICMPv6 Packet-Too-Big messages, visible on
    the incoming interface. The sender must adjust its path MTU and traffic
    must continue to flow.

Test05:
    IPsec transport mode. After switching both endpoints from tunnel to
    transport mode, encrypted communication must continue. Only ESP validation
    is performed; PMTUD is not expected here.

=cut
