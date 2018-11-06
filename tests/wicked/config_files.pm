# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Sanity checks of wicked related to config files
# Test scenarios:
# Test 1: Set up static addresses from legacy ifcfg files
# Test 2: Set up static addresses from wicked XML files
# Test 3: Set up dynamic addresses from legacy ifcfg files
# Test 4: Set up dynamic addresses from wicked XML files
# Test 5: Set up static routes from legacy ifcfg files
# Test 6: Set up static routes from wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use network_utils 'iface';


sub run {
    my ($self) = @_;
    my $iface = iface();
    $self->get_from_data('wicked/static_address/ifcfg-eth0',                      "/data/static_address/ifcfg-$iface");
    $self->get_from_data('wicked/static_address/static-addresses.xml',            "/data/static_address/static-addresses.xml");
    $self->get_from_data('wicked/static_address/ifroute-eth0',                    "/data/static_address/ifroute-$iface");
    $self->get_from_data('wicked/static_address/static-addresses-and-routes.xml', "/data/static_address/static-addresses-and-routes.xml");
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0',                     "/data/dynamic_address/ifcfg-$iface");
    $self->get_from_data('wicked/dynamic_address/dynamic-addresses.xml',          "/data/dynamic_address/dynamic-addresses.xml");
    assert_script_run("sed -i 's/xxx/$iface/g' /data/static_address/static-addresses.xml");
    assert_script_run("sed -i 's/xxx/$iface/g' /data/static_address/static-addresses-and-routes.xml");
    assert_script_run("sed -i 's/xxx/$iface/g' /data/dynamic_address/dynamic-addresses.xml");
    $self->before_scenario('Test 1', 'Set up static addresses from legacy ifcfg files');
    assert_script_run("cp /data/static_address/ifcfg-$iface /etc/sysconfig/network");
    assert_script_run("ifup $iface");
    $self->assert_wicked_state(ping_ip => '10.0.2.2', iface => $iface);
    $self->before_scenario('Test 2', 'Set up static addresses from wicked XML files', $iface);
    assert_script_run("wicked ifup --ifconfig /data/static_address/static-addresses.xml $iface");
    $self->assert_wicked_state(ping_ip => '10.0.2.2', iface => $iface);
    $self->before_scenario('Test 3', 'Set up dynamic addresses from legacy ifcfg files', $iface);
    assert_script_run("cp /data/dynamic_address/ifcfg-$iface /etc/sysconfig/network");
    assert_script_run("ifup $iface");
    $self->assert_wicked_state(ping_ip => '10.0.2.2', iface => $iface);
    $self->before_scenario('Test 4', 'Set up dynamic addresses from wicked XML files', $iface);
    assert_script_run("wicked ifup --ifconfig /data/dynamic_address/dynamic-addresses.xml $iface");
    $self->assert_wicked_state(ping_ip => '10.0.2.2', iface => $iface);
    $self->before_scenario('Test 5', 'Set up static routes from legacy ifcfg files', $iface);
    assert_script_run("cp /data/static_address/ifcfg-$iface /etc/sysconfig/network");
    assert_script_run("cp /data/static_address/ifroute-$iface /etc/sysconfig/network");
    assert_script_run("ifup $iface");
    $self->assert_wicked_state(ping_ip => '10.0.2.2', iface => $iface);
    validate_script_output("ip -4 route show", sub { m/default via 10.0.2.2/ });
    assert_script_run('ip -4 route show | grep "default" | grep -v "via' . $iface . '"');
    validate_script_output("ip -6 route show", sub { m/default via fd00:cafe:babe::1/ });
    $self->before_scenario('Test 6', 'Set up static routes from wicked XML files', $iface);
    assert_script_run("wicked ifup --ifconfig /data/static_address/static-addresses-and-routes.xml $iface");
    $self->assert_wicked_state(ping_ip => '10.0.2.2', iface => $iface);
}

1;
