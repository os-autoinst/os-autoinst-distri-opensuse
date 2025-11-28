# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Basic preparation as well as basic testsfor the IPSec
# Network topology used in this test:
#
#   LEFT HOST  <---------->  ROUTER  <----------->  RIGHT HOST
#   2001:1:1:1::2           2001:1:1:1::1          2002:1:1:1::2
#                           2002:1:1:1::1
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'ipsecbase';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use network_utils;

sub run_left {
    my ($self, $setup) = @_;

    my $ipsec_setting_left = {
        local_ip => $setup->{left_ip},
        remote_ip => $setup->{right_ip},
        new_local_net => $setup->{left_net},
        new_remote_net => $setup->{right_net},
    };

    $self->add_ipv6_addr(
        ip => $setup->{left_ip},
        plen => $self->get_net_prefix_len($setup->{left_net})
    );

    $self->check_ipv6_addr();
    barrier_wait('IPSEC_IP_SETUP_DONE');

    script_retry("ping -c 1 $setup->{middle_ip_01}", retry => 5);
    record_info('IP NEIGHBOR', script_output('ip neighbor show'));

    $self->add_ipv6_route(
        dst => $setup->{right_ip},
        via => $setup->{middle_ip_01}
    );

    barrier_wait('IPSEC_ROUTE_SETUP_DONE');

    record_info('IP ADDRESS', script_output('ip a'));
    record_info('IP ROUTE', script_output('ip -6 route'));

    script_retry("ping -c 1 $setup->{middle_ip_01}", retry => 5);
    script_retry("ping -c 1 $setup->{right_ip}", retry => 5);

    barrier_wait('IPSEC_ROUTE_SETUP_CHECK_DONE');

    $self->config_ipsec($ipsec_setting_left);

    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');

    assert_script_run("ping -c 8 $setup->{right_ip}");
    assert_script_run("ping6 -s 1300 -c 8 $setup->{right_ip}");

    barrier_wait('IPSEC_SET_MTU_DONE');

    assert_script_run("ping6 -c 8 $setup->{right_ip}");
    assert_script_run("ping6 -s 1300 -c 8 $setup->{right_ip}");

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');

    $self->{ipsec_mode} = 'transport';
    $self->config_ipsec($ipsec_setting_left);

    barrier_wait('IPSEC_TRANSPORT_MODE_SETUP_DONE');

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

    record_info('IP ADDRESS', script_output('ip a'));

    $self->add_ipv6_addr(
        ip => $setup->{middle_ip_01},
        dev => $dev0,
        plen => $self->get_net_prefix_len($setup->{middle_net_01})
    );

    $self->add_ipv6_addr(
        ip => $setup->{middle_ip_02},
        dev => $dev1,
        plen => $self->get_net_prefix_len($setup->{middle_net_02})
    );

    $self->check_ipv6_addr();

    script_retry("ping -c 1 $setup->{left_ip}", retry => 5);
    script_retry("ping -c 1 $setup->{right_ip}", retry => 5);

    record_info('IP NEIGHBOR', script_output('ip neighbor show'));

    barrier_wait('IPSEC_IP_SETUP_DONE');
    barrier_wait('IPSEC_ROUTE_SETUP_DONE');

    record_info('IP ADDRESS', script_output('ip a'));
    record_info('IP ROUTE', script_output('ip -6 route'));

    barrier_wait('IPSEC_ROUTE_SETUP_CHECK_DONE');
    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    assert_script_run("ip link set mtu 1300 dev $dev1");

    barrier_wait('IPSEC_SET_MTU_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');
    barrier_wait('IPSEC_TRANSPORT_MODE_SETUP_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('IPSEC_TRANSPORT_MODE_CHECK_DONE');
}

sub run_right {
    my ($self, $setup) = @_;

    my $ipsec_setting_right = {
        local_ip => $setup->{right_ip},
        remote_ip => $setup->{left_ip},
        new_local_net => $setup->{right_net},
        new_remote_net => $setup->{left_net},
    };

    my $dev0 = iface();

    $self->add_ipv6_addr(
        ip => $setup->{right_ip},
        plen => $self->get_net_prefix_len($setup->{right_net})
    );

    $self->check_ipv6_addr();
    barrier_wait('IPSEC_IP_SETUP_DONE');

    script_retry("ping -c 1 $setup->{middle_ip_02}", retry => 5);

    record_info('IP NEIGHBOR', script_output('ip neighbor show'));

    $self->add_ipv6_route(
        dst => $setup->{left_ip},
        via => $setup->{middle_ip_02}
    );

    barrier_wait('IPSEC_ROUTE_SETUP_DONE');

    record_info('IP ADDRESS', script_output('ip a'));
    record_info('IP ROUTE', script_output('ip -6 route'));

    script_retry("ping -c 1 $setup->{middle_ip_02}", retry => 5);
    script_retry("ping -c 1 $setup->{left_ip}", retry => 5);

    barrier_wait('IPSEC_ROUTE_SETUP_CHECK_DONE');

    $self->config_ipsec($ipsec_setting_right);

    barrier_wait('IPSEC_TUNNEL_MODE_SETUP_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('IPSEC_SET_MTU_DONE');

    script_run("timeout 20 tcpdump -i $dev0");

    barrier_wait('IPSEC_TUNNEL_MODE_CHECK_DONE');

    $self->{ipsec_mode} = 'transport';
    $self->config_ipsec($ipsec_setting_right);

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

    record_info('INTF STATUS', script_output('ip -s link show'));

    if ($role eq 'left') { $self->run_left($setup); }
    if ($role eq 'middle') { $self->run_middle($setup); }
    if ($role eq 'right') { $self->run_right($setup); }
}

1;
