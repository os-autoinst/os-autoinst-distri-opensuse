# SUSE's openQA tests
#
# Copyright 2017-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Basic preparation before any IPSec test
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "ipsecbase", -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use lockapi;
use network_utils;


sub run ($self) {

    select_serial_terminal;

    # This case using following 3 hosts scenario
    # host(left_ip) -------(middle_ip_01) router(middle_ip_01) ------ host(right_ip)

    my $setup = {
        'left_ip' => "2001:1:1:1::2",
        'right_ip' => "2002:1:1:1::2",
        'left_net' => "2001:1:1:1::/64",
        'right_net' => "2002:1:1:1::/64",
        'middle_ip_01' => "2001:1:1:1::1",
        'middle_ip_02' => "2002:1:1:1::1",
        'middle_net_01' => "2001:1:1:1::/64",
        'middle_net_02' => "2002:1:1:1::/64",
    };

    my $ipsec_setting_left = {
        'local_ip' => $setup->{left_ip},
        'remote_ip' => $setup->{right_ip},
        'new_local_net' => $setup->{left_net},
        'new_remote_net' => $setup->{right_net}
    };

    my $ipsec_setting_right = {
        'local_ip' => $setup->{right_ip},
        'remote_ip' => $setup->{left_ip},
        'new_local_net' => $setup->{right_net},
        'new_remote_net' => $setup->{left_net}
    };

    record_info('IPSEC_SETUP', get_var('IPSEC_SETUP'));

    if (get_var('IPSEC_SETUP') eq 'left') {
        $self->add_ipv6_addr(ip => $setup->{left_ip}, plen => $self->get_net_prefix_len($setup->{left_net}));
        $self->check_ipv6_addr();
        barrier_wait 'IPSEC_IP_SETUP_DONE';
        script_retry("ping -c 1 $setup->{middle_ip_01}", retry => 5);
        record_info('IP NEIGHBOR', script_output('ip neighbor show', proceed_on_failure => 1));
        $self->add_ipv6_route(dst => $setup->{right_ip}, via => $setup->{middle_ip_01});
        barrier_wait 'IPSEC_ROUTE_SETUP_DONE';
        record_info('IP ADDRESS', script_output('ip a', proceed_on_failure => 1));
        record_info('IP ROUTE', script_output('ip -6 route', proceed_on_failure => 1));
        script_retry("ping -c 1 $setup->{middle_ip_01}", retry => 5);
        script_retry("ping -c 1 $setup->{right_ip}", retry => 5);
        barrier_wait 'IPSEC_ROUTE_SETUP_CHECK_DONE';
        $self->config_ipsec($ipsec_setting_left);
        barrier_wait 'IPSEC_TUNNEL_MODE_SETUP_DONE';
        assert_script_run("ping -c 8 $setup->{right_ip}");
        barrier_wait 'IPSEC_SET_MTU_DONE';
        assert_script_run("ping6 -s 1300 -c 8 $setup->{right_ip}");
        barrier_wait 'IPSEC_TUNNEL_MODE_CHECK_DONE';
        $self->{ipsec_mode} = "transport";
        $self->config_ipsec($ipsec_setting_left);
        barrier_wait 'IPSEC_TRANSPORT_MODE_SETUP_DONE';
        assert_script_run("ping6 -s 1300 -c 8 $setup->{right_ip}");
        barrier_wait 'IPSEC_TRANSPORT_MODE_CHECK_DONE';
    }

    if (get_var('IPSEC_SETUP') eq 'middle') {
        my ($dev0, $dev1) = split("\n", iface(2));
        assert_script_run("sysctl net.ipv6.conf.all.forwarding=1");
        assert_script_run("ip link set $dev0 up");
        assert_script_run("ip link set $dev1 up");
        record_info('IP ADDRESS', script_output('ip a', proceed_on_failure => 1));
        $self->add_ipv6_addr(ip => $setup->{middle_ip_01}, dev => $dev0, plen => $self->get_net_prefix_len($setup->{middle_net_01}));
        $self->add_ipv6_addr(ip => $setup->{middle_ip_02}, dev => $dev1, plen => $self->get_net_prefix_len($setup->{middle_net_02}));
        $self->check_ipv6_addr();
        script_retry("ping -c 1 $setup->{left_ip}", retry => 5);
        script_retry("ping -c 1 $setup->{right_ip}", retry => 5);
        record_info('IP NEIGHBOR', script_output('ip neighbor show', proceed_on_failure => 1));
        barrier_wait 'IPSEC_IP_SETUP_DONE';
        barrier_wait 'IPSEC_ROUTE_SETUP_DONE';
        record_info('IP ADDRESS', script_output('ip a', proceed_on_failure => 1));
        record_info('IP ROUTE', script_output('ip -6 route', proceed_on_failure => 1));
        barrier_wait 'IPSEC_ROUTE_SETUP_CHECK_DONE';
        barrier_wait 'IPSEC_TUNNEL_MODE_SETUP_DONE';
        assert_script_run("ip l s mtu 1300 dev $dev1");
        barrier_wait 'IPSEC_SET_MTU_DONE';
        barrier_wait 'IPSEC_TUNNEL_MODE_CHECK_DONE';
        barrier_wait 'IPSEC_TRANSPORT_MODE_SETUP_DONE';
        barrier_wait 'IPSEC_TRANSPORT_MODE_CHECK_DONE';
    }

    if (get_var('IPSEC_SETUP') eq 'right') {
        my $dev0 = iface();
        $self->add_ipv6_addr(ip => $setup->{right_ip}, plen => $self->get_net_prefix_len($setup->{right_net}));
        $self->check_ipv6_addr();
        barrier_wait 'IPSEC_IP_SETUP_DONE';
        script_retry("ping -c 1 $setup->{middle_ip_02}", retry => 5);
        record_info('IP NEIGHBOR', script_output('ip neighbor show', proceed_on_failure => 1));
        $self->add_ipv6_route(dst => $setup->{left_ip}, via => $setup->{middle_ip_02});
        barrier_wait 'IPSEC_ROUTE_SETUP_DONE';
        record_info('IP ADDRESS', script_output('ip a', proceed_on_failure => 1));
        record_info('IP ROUTE', script_output('ip -6 route', proceed_on_failure => 1));
        script_retry("ping -c 1 $setup->{middle_ip_02}", retry => 5);
        script_retry("ping -c 1 $setup->{left_ip}", retry => 5);
        barrier_wait 'IPSEC_ROUTE_SETUP_CHECK_DONE';
        $self->config_ipsec($ipsec_setting_right);
        barrier_wait 'IPSEC_TUNNEL_MODE_SETUP_DONE';
        assert_script_run("tcpdump -i $dev0 esp -c 4");
        barrier_wait 'IPSEC_SET_MTU_DONE';
        barrier_wait 'IPSEC_TUNNEL_MODE_CHECK_DONE';
        $self->{ipsec_mode} = "transport";
        $self->config_ipsec($ipsec_setting_right);
        barrier_wait 'IPSEC_TRANSPORT_MODE_SETUP_DONE';
        assert_script_run("tcpdump -i $dev0 esp -c 4");
        barrier_wait 'IPSEC_TRANSPORT_MODE_CHECK_DONE';
    }
}

1;
