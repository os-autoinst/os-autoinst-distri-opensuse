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
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base 'wickedbase';
use strict;
use testapi;

our $iface = '';

sub reset_network {
    assert_script_run("ifdown $iface");
    assert_script_run("ifbind.sh unbind $iface");
    type_string("rm /etc/sysconfig/network/ifcfg-$iface\n");
    assert_script_run("ifbind.sh bind $iface");
}

sub run {
    my ($self) = @_;
    $iface = script_output('echo $(ls /sys/class/net/ | grep -v lo | head -1)');
    $self->get_from_data('wicked/static_address/ifcfg-eth0',             "/data/static_address/ifcfg-$iface");
    $self->get_from_data('wicked/static_address/static-addresses.xml',   "/data/static_address/static-addresses.xml");
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0',            "/data/dynamic_address/ifcfg-$iface");
    $self->get_from_data('wicked/dynamic_address/dynamic-addresses.xml', "/data/dynamic_address/dynamic-addresses.xml");
    $self->get_from_data('wicked/ifbind.sh',                             '/bin/ifbind.sh', executable => 1);
    assert_script_run("sed -i 's/xxx/$iface/g' /data/static_address/static-addresses.xml");
    assert_script_run("sed -i 's/xxx/$iface/g' /data/dynamic_address/dynamic-addresses.xml");
    reset_network();
    type_string("#***Test 1: Set up static addresses from legacy ifcfg files***\n");
    assert_script_run("cp /data/static_address/ifcfg-$iface /etc/sysconfig/network");
    assert_script_run("ifup $iface");
    $self->assert_wicked_state();
    reset_network();
    type_string("#***Test 2: Set up static addresses from wicked XML files***\n");
    assert_script_run("wicked ifup --ifconfig /data/static_address/static-addresses.xml $iface");
    $self->assert_wicked_state();
    reset_network();
    type_string("#***Test 3: Set up dynamic addresses from legacy ifcfg files***\n");
    assert_script_run("cp /data/dynamic_address/ifcfg-$iface /etc/sysconfig/network");
    assert_script_run("ifup $iface");
    $self->assert_wicked_state();
    reset_network();
    type_string("#***Test 4: Set up dynamic addresses from wicked XML files***\n");
    assert_script_run("wicked ifup --ifconfig /data/static_address/static-addresses.xml $iface");
    $self->assert_wicked_state();
    $self->save_and_upload_wicked_log();
}

1;
