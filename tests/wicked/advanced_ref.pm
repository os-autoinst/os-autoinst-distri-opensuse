# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked. Reference machine which used to support tests
# running on SUT
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, Jose Lausuch <jalausuch@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use lockapi;
use mmapi;

sub create_tunnel_with_commands {

    my ($self, $type, $mode, $sub_mask) = @_;
    my $local_ip  = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    my $tunnel_ip = $self->get_ip(is_wicked_ref => 1, type => $type);
    assert_script_run("ip tunnel add $type mode $mode remote $remote_ip local $local_ip");
    assert_script_run("ip link set $type up");
    assert_script_run("ip addr add $tunnel_ip/$sub_mask dev $type");
    assert_script_run("ip addr");
}

sub run {
    my ($self) = @_;
    my $openvpn_server = '/etc/openvpn/server.conf';

    record_info('Test 1', 'Create a GRE interface from legacy ifcfg files');
    $self->create_tunnel_with_commands("gre1", "gre", "24");
    mutex_wait('test_1_ready');
    assert_script_run("ip addr flush dev gre1");
    assert_script_run("ip tunnel delete gre1");

    record_info('Test 2', 'Create a GRE interface from wicked XML files');
    $self->create_tunnel_with_commands("gre1", "gre", "24");
    mutex_wait('test_2_ready');
    assert_script_run("ip addr flush dev gre1");
    assert_script_run("ip tunnel delete gre1");

    record_info('Test 3', 'Create a SIT interface from legacy ifcfg files');
    $self->create_tunnel_with_commands("sit1", "sit", "127");
    mutex_wait('test_3_ready');
    assert_script_run("ip addr flush dev sit1");
    assert_script_run("ip tunnel delete sit1");

    record_info('Test 4', 'Create a SIT interface from from Wicked XML files');
    $self->create_tunnel_with_commands("sit1", "sit", "127");
    mutex_wait('test_4_ready');
    assert_script_run("ip addr flush dev sit1");
    assert_script_run("ip tunnel delete sit1");

    record_info('Test 5', 'Create a IPIP interface from legacy ifcfg files');
    $self->create_tunnel_with_commands("tunl1", "ipip", "24");
    mutex_wait('test_5_ready');
    assert_script_run("ip addr flush dev tunl1");
    assert_script_run("ip tunnel delete tunl1");

    record_info('Test 6', 'Create a IPIP interface from Wicked XML files');
    $self->create_tunnel_with_commands("tunl1", "ipip", "24");
    mutex_wait('test_6_ready');
    assert_script_run("ip addr flush dev tunl1");
    assert_script_run("ip tunnel delete tunl1");

    record_info('Test 7', 'Create a TUN interface from legacy ifcfg files');
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg-tun1_ref', $config);
    $self->get_from_data('wicked/server.conf',    $openvpn_server);
    assert_script_run("sed \'s/device/tun1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tun1", 1);
    mutex_wait('test_7_ready');
    $self->cleanup($config, "tun1");

    record_info('Test 8', 'Create a TUN interface from Wicked XML files');
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg-tun1_ref', $config);
    $self->get_from_data('wicked/server.conf',    $openvpn_server);
    assert_script_run("sed \'s/device/tun1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tun1", 1);
    mutex_wait('test_8_ready');
    $self->cleanup($config, "tun1");

    record_info('Test 9', 'Create a TAP interface from legacy ifcfg files');
    my $config = '/etc/sysconfig/network/ifcfg-tap1';
    $self->get_from_data('wicked/ifcfg-tap1_ref', $config);
    $self->get_from_data('wicked/server.conf',    $openvpn_server);
    assert_script_run("sed \'s/device/tap1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tap1", 1);
    mutex_wait('test_9_ready');
    $self->cleanup($config, "tap1");

    record_info('Test 10', 'Create a TAP interface from Wicked XML files');
    my $config = '/etc/sysconfig/network/ifcfg-tap1';
    $self->get_from_data('wicked/ifcfg-tap1_ref', $config);
    $self->get_from_data('wicked/server.conf',    $openvpn_server);
    assert_script_run("sed \'s/device/tap1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tap1", 1);
    mutex_wait('test_10_ready');
    $self->cleanup($config, "tap1");

    record_info('Test 11', 'Create Bridge interface from legacy ifcfg files');
    # Note: No need to create a bridge interface, as the SUT will ping
    #       the IP of eth0 already configured.
    mutex_wait('test_11_ready');

    record_info('Test 12', 'Create Bridge interface from Wicked XML files');
    # Note: No need to create a bridge interface, as the SUT will ping
    #       the IP of eth0 already configured.
    mutex_wait('test_12_ready');

    # Placeholder for Test 13: Create a team interface from legacy ifcfg files
    # Placeholder for Test 14: Create a team interface from Wicked XML files
}

1;
