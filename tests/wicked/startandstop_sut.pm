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
