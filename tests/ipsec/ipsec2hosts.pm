# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Basic direct host-to-host IPsec connectivity test for two baremetal nodes.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package ipsec2hosts;
use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use network_utils;
use Kernel::net_tests qw(
  config_ipsec
  dump_ipsec_debug
  validate_tcpdump
  capture_tcpdump
);
use Kernel::multimachine_topology qw(
  get_node_by_role
  get_network_by_id
  get_interface
  require_field
);

sub get_ipsec_2hosts_setup {
    my $left = get_node_by_role('left');
    my $right = get_node_by_role('right');
    my $left_if = get_interface($left, 0);
    my $right_if = get_interface($right, 0);
    my $network = get_network_by_id($left_if->{network});

    return {
        left_ipv4 => require_field($left_if->{ipv4}, 'left IPv4 missing from multimachine_topology'),
        right_ipv4 => require_field($right_if->{ipv4}, 'right IPv4 missing from multimachine_topology'),
        left_ipv6 => require_field($left_if->{ipv6}, 'left IPv6 missing from multimachine_topology'),
        right_ipv6 => require_field($right_if->{ipv6}, 'right IPv6 missing from multimachine_topology'),
        shared_net_v4 => require_field($network->{ipv4_cidr}, 'shared IPv4 CIDR missing from multimachine_topology'),
        shared_net_v6 => require_field($network->{ipv6_cidr}, 'shared IPv6 CIDR missing from multimachine_topology'),
    };
}

sub run_left {
    my ($self, $setup) = @_;

    record_info("Test01: connectivity", "Ping peer before IPsec");
    script_retry("ping -c 3 $setup->{right_ipv6}", retry => 5);

    config_ipsec(
        local_ip => $setup->{left_ipv6},
        remote_ip => $setup->{right_ipv6},
        new_local_net => "$setup->{left_ipv6}/128",
        new_remote_net => "$setup->{right_ipv6}/128",
    );

    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');
    dump_ipsec_debug();

    record_info("Test02: mode tunnel", "Ping over IPsec");
    assert_script_run("ping -c 8 $setup->{right_ipv6}");
    assert_script_run("ping6 -s 1200 -c 8 $setup->{right_ipv6}");

    barrier_wait('IPSEC_SET_MTU_DONE');

    record_info("Test03: MTU", "MTU reduced on peer interface");
    assert_script_run("ping -c 8 $setup->{right_ipv6}");
    assert_script_run("ping6 -s 1200 -c 8 $setup->{right_ipv6}");

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');

    config_ipsec(
        local_ip => $setup->{left_ipv6},
        remote_ip => $setup->{right_ipv6},
        new_local_net => "$setup->{left_ipv6}/128",
        new_remote_net => "$setup->{right_ipv6}/128",
        mode => 'transport',
    );

    barrier_wait('IPSEC_TRANSPORT_MODE_SETUP_DONE');
    dump_ipsec_debug();

    record_info("Test04: mode transport", "Use transport mode of IPsec");
    assert_script_run("ping -c 8 $setup->{right_ipv6}");
    assert_script_run("ping6 -s 1200 -c 8 $setup->{right_ipv6}");

    barrier_wait('IPSEC_TRANSPORT_MODE_CHECK_DONE');
    barrier_wait('IPSEC_TESTS_DONE');
}

sub run_right {
    my ($self, $setup) = @_;
    my $dev = iface(0);
    my $dump;

    record_info("Test01: connectivity", "Ping peer before IPsec");
    script_retry("ping -c 3 $setup->{left_ipv6}", retry => 5);

    config_ipsec(
        local_ip => $setup->{right_ipv6},
        remote_ip => $setup->{left_ipv6},
        new_local_net => "$setup->{right_ipv6}/128",
        new_remote_net => "$setup->{left_ipv6}/128",
    );

    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');
    dump_ipsec_debug();

    record_info("Test02: mode tunnel", "Capture ESP traffic");
    $dump = capture_tcpdump($dev, 15);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => '0x26c44388', dev => $dev);

    assert_script_run("ip link set mtu 1300 dev $dev");

    barrier_wait('IPSEC_SET_MTU_DONE');

    record_info("Test03: MTU", "Capture ESP traffic after MTU reduction");
    $dump = capture_tcpdump($dev, 15);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => '0x26c44388', dev => $dev);

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');

    config_ipsec(
        local_ip => $setup->{right_ipv6},
        remote_ip => $setup->{left_ipv6},
        new_local_net => "$setup->{right_ipv6}/128",
        new_remote_net => "$setup->{left_ipv6}/128",
        mode => 'transport',
    );

    barrier_wait('IPSEC_TRANSPORT_MODE_SETUP_DONE');
    dump_ipsec_debug();

    record_info("Test04: mode transport", "Capture ESP traffic in transport mode");
    $dump = capture_tcpdump($dev, 15);
    validate_tcpdump(dump => $dump, check => ['esp'], spi => '0x26c44388', dev => $dev);

    barrier_wait('IPSEC_TRANSPORT_MODE_CHECK_DONE');
    barrier_wait('IPSEC_TESTS_DONE');
}

sub run {
    my ($self) = @_;
    my $role = get_required_var('ROLE');
    my $setup = get_ipsec_2hosts_setup();

    record_info('ROLE', $role);
    record_info('IP ADDRESS', script_output('ip a'));
    record_info('IP ROUTE', script_output('ip -6 route', proceed_on_failure => 1));

    if ($role eq 'left') { $self->run_left($setup); }
    elsif ($role eq 'right') { $self->run_right($setup); }
    else { die "Unknown ROLE '$role': expected 'left' or 'right'"; }
}

sub pre_run_hook {
    my ($self) = @_;
    select_serial_terminal;
    zypper_call('install tcpdump');
    quit_packagekit();
    ensure_service_disabled('apparmor');
    ensure_service_disabled($self->firewall);
}

1;

=head1 Description

ipsec2hosts - Multimachine IPsec test verifying direct host-to-host
connectivity, tunnel/transport mode operation, and reduced MTU handling
across a two-host baremetal IPv6 topology.

This module consumes multimachine topology data from
C<test_data/kernel/multimachine/ipsec_2hosts.yaml> and verifies direct IPv6
connectivity between two baremetal nodes before and after configuring IPsec
policies and state.

The test first verifies plain connectivity, then configures tunnel mode and
checks encrypted traffic with both default and larger IPv6 payloads. The
transport interface MTU is reduced to ensure the tunnel remains functional in
the smaller-MTU setup. Afterwards the test switches to transport mode and
verifies connectivity again. TCP dumps on the peer side are used to validate
that ESP traffic is present during the encrypted phases.

Unlike C<ipsec3hosts>, this module does not model a routed three-host
topology and does not exercise PMTUD through a dedicated middle router.

=cut
