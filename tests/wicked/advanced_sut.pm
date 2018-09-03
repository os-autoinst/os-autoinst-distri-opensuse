# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test scenarios:
# Test 1 : Create a GRE interface from legacy ifcfg files
# Test 2 : Create a GRE interface from wicked XML files
# Test 3 : Create a SIT interface from legacy ifcfg files
# Test 4 : Create a SIT interface from Wicked XML files
# Test 5 : Create a IPIP  interface from legacy ifcfg files
# Test 6 : Create a IPIP interface from Wicked XML files
# Test 7 : Create a tun interface from legacy ifcfg files
# Test 8 : Create a tun interface from Wicked XML files
# Test 9 : Create a tap interface from legacy ifcfg files
# Test 10: Create a tap interface from Wicked XML files
# Test 11: Create Bridge interface from legacy ifcfg files
# Test 12: Create a Bridge interface from Wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, Jose Lausuch <jalausuch@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use network_utils 'iface';
use lockapi;
use mmapi;

our $openvpn_client = '/etc/openvpn/client.conf';

sub get_test_result {
    my ($self, $type, $ip_version) = @_;
    my $timeout = "60";
    my $ip      = $self->get_ip(is_wicked_ref => 1, type => $type);
    my $ret     = $self->ping_with_timeout(ip => "$ip", timeout => "$timeout", ip_version => $ip_version);
    if (!$ret) {
        record_info("PING FAILED", "Can't ping IP $ip", result => 'fail');
        return "FAILED";
    }
    else {
        return "PASSED";
    }
}

sub setup_tunnel {
    my ($self, $config, $type) = @_;
    my $local_ip  = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    my $tunnel_ip = $self->get_ip(is_wicked_ref => 0, type => $type);
    assert_script_run("sed \'s/local_ip/$local_ip/\' -i $config");
    assert_script_run("sed \'s/remote_ip/$remote_ip/\' -i $config");
    assert_script_run("sed \'s/tunnel_ip/$tunnel_ip/\' -i $config");
    assert_script_run("cat $config");
    assert_script_run("wicked ifup --timeout infinite $type");
    assert_script_run('ip a');
}

sub setup_bridge {
    my ($self, $config, $dummy) = @_;
    my $local_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    assert_script_run("sed \'s/ip_address/$local_ip/\' -i $config");
    assert_script_run("cat $config");
    assert_script_run("wicked ifup --timeout infinite br0");
    if ($dummy ne '') {
        assert_script_run("cat $dummy");
        assert_script_run("wicked ifup --timeout infinite dummy0");
    }
    assert_script_run('ip a');
}

sub setup_openvpn_client {
    my ($self, $device) = @_;
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    $self->get_from_data('wicked/openvpn/client.conf', $openvpn_client);
    assert_script_run("sed \'s/remote_ip/$remote_ip/\' -i $openvpn_client");
    assert_script_run("sed \'s/device/$device/\' -i $openvpn_client");
}

sub run {
    my ($self) = @_;
    my %results;
    my $iface = iface();


    $self->before_scenario('Test 1', 'Create a gre interface from legacy ifcfg files');
    my $config = '/etc/sysconfig/network/ifcfg-gre1';
    $self->get_from_data('wicked/ifcfg/gre1', $config);
    $self->setup_tunnel($config, "gre1");
    $results{1} = $self->get_test_result("gre1", "");
    mutex_create("test_1_ready");
    $self->cleanup($config, "gre1");

    $self->before_scenario('Test 2', 'Create a gre interface from wicked XML files', $iface);
    $config = '/etc/wicked/ifconfig/gre.xml';
    $self->get_from_data('wicked/xml/gre.xml', $config);
    $self->setup_tunnel($config, "gre1");
    $results{2} = $self->get_test_result("gre1", "");
    mutex_create("test_2_ready");
    $self->cleanup($config, "gre1");

    $self->before_scenario('Test 3', 'Create a SIT interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-sit1';
    $self->get_from_data('wicked/ifcfg/sit1', $config);
    $self->setup_tunnel($config, "sit1");
    $results{3} = $self->get_test_result("sit1", "v6");
    mutex_create("test_3_ready");
    $self->cleanup($config, "sit1");

    $self->before_scenario('Test 4', 'Create a SIT interface from wicked XML files', $iface);
    $config = '/etc/wicked/ifconfig/sit.xml';
    $self->get_from_data('wicked/xml/sit.xml', $config);
    $self->setup_tunnel($config, "sit1");
    $results{4} = $self->get_test_result("sit1", "v6");
    mutex_create("test_4_ready");
    $self->cleanup($config, "sit1");

    $self->before_scenario('Test 5', 'Create a IPIP interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-tunl1';
    $self->get_from_data('wicked/ifcfg/tunl1', $config);
    $self->setup_tunnel($config, "tunl1");
    $results{5} = $self->get_test_result("tunl1", "");
    mutex_create("test_5_ready");
    $self->cleanup($config, "tunl1");

    $self->before_scenario('Test 6', 'Create a IPIP interface from wicked XML files', $iface);
    $config = '/etc/wicked/ifconfig/ipip.xml';
    $self->get_from_data('wicked/xml/ipip.xml', $config);
    $self->setup_tunnel($config, "tunl1");
    $results{6} = $self->get_test_result("tunl1", "");
    mutex_create("test_6_ready");
    $self->cleanup($config, "tunl1");

    $self->before_scenario('Test 7', 'Create a TUN interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg/tun1_sut', $config);
    $self->setup_openvpn_client("tun1");
    $self->setup_tuntap($config, "tun1", 0);
    $results{7} = $self->get_test_result("tun1", "");
    mutex_create("test_7_ready");
    $self->cleanup($config, "tun1");

    $self->before_scenario('Test 8', 'Create a TUN interface from wicked XML files', $iface);
    $config = '/etc/wicked/ifconfig/tun.xml';
    $self->get_from_data('wicked/xml/tun.xml', $config);
    $self->setup_openvpn_client("tun1");
    $self->setup_tuntap($config, "tun1");
    $results{8} = $self->get_test_result("tun1", "");
    mutex_create("test_8_ready");
    $self->cleanup($config, "tun1");

    $self->before_scenario('Test 9', 'Create a TAP interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-tap1';
    $self->get_from_data('wicked/ifcfg/tap1_sut', $config);
    $self->setup_openvpn_client("tap1");
    $self->setup_tuntap($config, "tap1", 0);
    $results{9} = $self->get_test_result("tap1", "");
    mutex_create("test_9_ready");
    $self->cleanup($config, "tap1");

    $self->before_scenario('Test 10', 'Create a TAP interface from Wicked XM files', $iface);
    $config = '/etc/wicked/ifconfig/tap.xml';
    $self->get_from_data('wicked/xml/tap.xml', $config);
    $self->setup_openvpn_client("tap1");
    $self->setup_tuntap($config, "tap1", 0);
    $results{10} = $self->get_test_result("tap1", "");
    mutex_create("test_10_ready");
    $self->cleanup($config, "tap1");

    $self->before_scenario('Test 11', 'Create Bridge interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy = '/etc/sysconfig/network/ifcfg-dummy0';
    $self->get_from_data('wicked/ifcfg/br0',    $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy);
    $results{11} = $self->get_test_result("br0", "");
    mutex_create("test_11_ready");
    $self->cleanup($config, "br0");
    $self->cleanup($dummy,  "dummy0");

    $self->before_scenario('Test 12', 'Create Bridge interface from Wicked XM files', $iface);
    $config = '/etc/wicked/ifconfig/bridge.xml';
    $self->get_from_data('wicked/xml/bridge.xml', $config);
    assert_script_run("ifdown eth0");
    assert_script_run("rm /etc/sysconfig/network/ifcfg-eth0");
    $self->setup_bridge($config, '');
    $results{12} = $self->get_test_result("br0", "");
    mutex_create("test_12_ready");
    $self->cleanup($config, "br0");

    ## processing overall results
    wait_for_children;
    my $failures = grep { $_ eq "FAILED" } values %results;
    if ($failures > 0) {
        foreach my $key (sort keys %results) {
            diag "\n Test$key --- " . $results{$key};
        }
        die "Some tests failed";
    }
}

1;
