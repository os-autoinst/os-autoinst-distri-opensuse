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
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, Jose Lausuch <jalausuch@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use lockapi;
use mmapi;

sub get_test_result {
    my ($self, $type, $ip_version) = @_;
    my $timeout = "60";
    my $ip      = $self->get_ip(is_wicked_ref => 1, type => $type);
    my $ret     = $self->ping_with_timeout(ip => "$ip", timeout => "$timeout", ip_version => $ip_version);
    if (!$ret) {
        record_info("Can't ping IP $ip", result => 'fail');
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
    assert_script_run("ifup $type");
    assert_script_run('ip a');
}

sub setup_bridge {
    my ($self, $config, $dummy, $br_name, $dummy_name) = @_;
    my $local_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    assert_script_run("sed \'s/ip_address/$local_ip/\' -i $config");
    assert_script_run("cat $config");
    assert_script_run("cat $dummy");
    assert_script_run("ifup $br_name");
    assert_script_run("ifup $dummy_name");
    assert_script_run('ip a');
}

sub run {
    my ($self) = @_;
    my %results;
    my $iface = script_output('ls /sys/class/net/ | grep -v lo | head -1');

    $self->before_scenario('Test 1', 'Create a gre interface from legacy ifcfg files');
    my $config = '/etc/sysconfig/network/ifcfg-gre1';
    $self->get_from_data('wicked/ifcfg-gre1_', $config, add_suffix => 1);
    $self->setup_tunnel($config, "gre1");
    $results{1} = $self->get_test_result("gre1", "");
    mutex_create("test_1_ready");
    assert_script_run("ifdown gre1");
    assert_script_run("rm $config");

    # Placeholder for Test 2: Create a GRE interface from Wicked XML files

    $self->before_scenario('Test 3', 'Create a SIT interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-sit1';
    $self->get_from_data('wicked/ifcfg-sit1_', $config, add_suffix => 1);
    $self->setup_tunnel($config, "sit1");
    $results{3} = $self->get_test_result("sit1", "v6");
    assert_script_run("ifdown sit1");
    assert_script_run("rm $config");
    mutex_create("test_3_ready");

    # Placeholder for Test 4: Create a SIT interface from Wicked XML files

    $self->before_scenario('Test 5', 'Create a IPIP  interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-tunl1';
    $self->get_from_data('wicked/ifcfg-tunl1_', $config, add_suffix => 1);
    $self->setup_tunnel($config, "tunl1");
    $results{3} = $self->get_test_result("tunl1", "");
    mutex_create("test_5_ready");
    assert_script_run("ifdown tunl1");
    assert_script_run("rm $config");

    # Placeholder for Test 6: Create a IPIP interface from Wicked XML files

    # Placeholder for Test 7: Create a tun interface from legacy ifcfg files
    # Placeholder for Test 8: Create a tun interface from Wicked XML files

    # Placeholder for Test 9: Create a tap interface from legacy ifcfg files
    # Placeholder for Test 10: Create a tap interface from Wicked XML files


    $self->before_scenario('Test 11', 'Create Bridge interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy = '/etc/sysconfig/network/ifcfg-dummy0';
    $self->get_from_data('wicked/ifcfg-br0_',    $config, add_suffix => 1);
    $self->get_from_data('wicked/ifcfg-dummy0_', $dummy,  add_suffix => 1);
    $self->setup_bridge($config, $dummy, "br0", "dummy0");
    $results{4} = $self->get_test_result("br0", "");
    assert_script_run("ifdown br0");
    assert_script_run("ifdown dummy0");
    assert_script_run("rm $config");
    assert_script_run("rm $dummy");
    mutex_create("test_11_ready");

    # Placeholder for Test 12: Create a Bridge interface from Wicked XML files

    # Placeholder for Test 13: Create a team interface from legacy ifcfg files
    # Placeholder for Test 14: Create a team interface from Wicked XML files

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
