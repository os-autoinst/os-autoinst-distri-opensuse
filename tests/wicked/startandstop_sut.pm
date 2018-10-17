# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Startandstop test cases for wicked. SUT machine.
# Test scenarios:
# Test 1  : Bridge - ifreload
# Test 2  : Bridge - ifup, ifreload
# Test 3  : Bridge - ifup, remove all config, ifreload
# Test 4  : Bridge - ifup, remove one config, ifreload
# Test 5  : Standalone card - ifdown, ifreload
# Test 6  : VLAN - ifdown, modify config, ifreload
# Test 7  : Bridge - ifdown, create new config, ifreload, ifdown, ifup
# Test 8  : Bridge - ifdown, remove one config, ifreload, ifdown, ifup
# Test 9  : VLAN - ifdown, modify one config, ifreload, ifdown, ifup
# Test 10 : VLAN - ifup all, ifdown one card
# Test 11 : Complex layout - ifup twice
# Test 12 : Complex layout - ifup 3 times
# Test 13 : Complex layout - ifdown
# Test 14 : Complex layout - ifdown twice
# Test 15 : Complex layout - ifdown 3 times
# Test 16 : Complex layout - ifreload
# Test 17 : Complex layout - ifreload twice
# Test 18 : Complex layout - ifreload, config change, ifreload
# Test 19 : Complex layout - ifup, ifstatus
# Test 20 : Complex layout - ifup, ifstatus, ifdown, ifstatus
# Test 21 : SIT tunnel - ifdown
# Test 22 : OpenVPN tunnel - ifdown
#
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use network_utils 'iface';
use lockapi;
use mmapi;

sub run {
    my ($self) = @_;
    my %results;
    my $config;
    my $dummy;
    my $iface = iface();

    $self->before_scenario('Test 1', 'Bridge - ifreload', $iface);
    $config = '/etc/sysconfig/network/ifcfg-br0';
    $dummy  = '/etc/sysconfig/network/ifcfg-dummy0';
    $self->get_from_data('wicked/ifcfg/br0',    $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifreload');
    $results{1} = $self->get_test_result("br0", "");
    mutex_create("test_1_ready");
    $self->cleanup($config, "br0");
    $self->cleanup($dummy,  "dummy0");

    $self->before_scenario('Test 2', 'Bridge - ifup, ifreload', $iface);
    $self->get_from_data('wicked/ifcfg/br0',    $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    $self->setup_bridge($config, $dummy, 'ifreload');
    $results{2} = $self->get_test_result("br0", "");
    mutex_create("test_2_ready");
    $self->cleanup($config, "br0");
    $self->cleanup($dummy,  "dummy0");

    $self->before_scenario('Test 3', 'Bridge - ifup, remove all config, ifreload', $iface);
    $self->get_from_data('wicked/ifcfg/br0',    $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    assert_script_run("rm /etc/sysconfig/network/ifcfg-$iface $config $dummy");
    assert_script_run("wicked ifreload --timeout infinite all");
    my $res = script_run("ip link|grep 'dummy0\|br0'");
    $results{3} = $res ? "PASSED" : "FAILED";
    mutex_create("test_3_ready");

    $self->before_scenario('Test 4', 'Bridge - ifup, remove all config, ifreload', $iface);
    $self->get_from_data('wicked/ifcfg/br0',    $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    assert_script_run("rm $config");
    assert_script_run("wicked ifreload --timeout infinite all");
    my $res1 = script_run("ip link|grep br0");
    my $res2 = script_run("ip link|grep dummy0");
    $results{4} = $res1 && !$res2 ? "PASSED" : "FAILED";
    $self->cleanup($dummy, "dummy0");
    mutex_create("test_4_ready");

    $self->before_scenario('Test 5', 'Standalone card - ifdown, ifreload', $iface);
    $config = '/etc/sysconfig/network/ifcfg-' . $iface;
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', $config);
    assert_script_run("ifdown $iface");
    assert_script_run("wicked ifreload  $iface");
    my $static_ip = $self->get_ip(type => 'host', no_mask => 1);
    my $dhcp_ip = $self->get_current_ip($iface);
    if (defined($dhcp_ip) && $static_ip ne $dhcp_ip) {
        $results{5} = $self->get_test_result('host');
    } else {
        record_info('DHCP failed', 'current ip: ' . ($dhcp_ip || 'none'), result => 'fail');
        $results{5} = 'FAILED';
    }
    mutex_create("test_5_ready");

    $self->before_scenario('Test 22', 'OpenVPN tunnel - ifdown', $iface);
    $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg/tun1_sut', $config);
    $self->setup_openvpn_client('tun1');
    $self->setup_tuntap($config, 'tun1', 0);
    $results{22} = $self->get_test_result('tun1');
    if ($results{22} ne 'FAILED') {
        assert_script_run('wicked ifdown --timeout infinite tun1');
        my $res1 = script_run('ip link | grep tun1');
        my $res2 = script_run('systemctl -q is-active openvpn@client');
        if (!$res1 || !$res2) {
            $results{22} = 'FAILED';
        }
    }
    mutex_create("test_22_ready");
    $self->cleanup($config, "tun1");

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
