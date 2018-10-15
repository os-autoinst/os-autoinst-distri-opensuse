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
    $self->get_from_data('wicked/ifcfg/tun1_ref',      $config);
    $self->get_from_data('wicked/openvpn/server.conf', $openvpn_server);
    assert_script_run("sed \'s/device/tun1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tun1", 1);
    mutex_wait('test_7_ready');
    $self->cleanup($config, "tun1");

    record_info('Test 8', 'Create a TUN interface from Wicked XML files');
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg/tun1_ref',      $config);
    $self->get_from_data('wicked/openvpn/server.conf', $openvpn_server);
    assert_script_run("sed \'s/device/tun1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tun1", 1);
    mutex_wait('test_8_ready');
    $self->cleanup($config, "tun1");

    record_info('Test 9', 'Create a TAP interface from legacy ifcfg files');
    my $config = '/etc/sysconfig/network/ifcfg-tap1';
    $self->get_from_data('wicked/ifcfg/tap1_ref',      $config);
    $self->get_from_data('wicked/openvpn/server.conf', $openvpn_server);
    assert_script_run("sed \'s/device/tap1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tap1", 1);
    mutex_wait('test_9_ready');
    $self->cleanup($config, "tap1");

    record_info('Test 10', 'Create a TAP interface from Wicked XML files');
    my $config = '/etc/sysconfig/network/ifcfg-tap1';
    $self->get_from_data('wicked/ifcfg/tap1_ref',      $config);
    $self->get_from_data('wicked/openvpn/server.conf', $openvpn_server);
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

}

1;
