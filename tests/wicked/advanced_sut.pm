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

sub run {
    my ($self) = @_;
    my %results;
    my $iface = script_output('ls /sys/class/net/ | grep -v lo | head -1');

    my $config = '/etc/sysconfig/network/ifcfg-gre1';
    $self->get_from_data('wicked/ifcfg-gre1_', $config, add_suffix => 1);
    $self->before_scenario('Test 1', 'Create a gre interface from legacy ifcfg files');
    $self->setup_tunnel($config, "gre1");
    $results{1} = $self->get_test_result("gre1", "");
    mutex_create("test_1_ready");
    assert_script_run("ifdown gre1");
    assert_script_run("rm $config");

    $self->before_scenario('Test 3', 'Create a SIT interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-sit1';
    $self->get_from_data('wicked/ifcfg-sit1_', $config, add_suffix => 1);
    $self->setup_tunnel($config, "sit1");
    $results{3} = $self->get_test_result("sit1", "v6");
    mutex_create("test_3_ready");

    $self->before_scenario('Test 6', 'Create a IPIP  interface from legacy ifcfg files', $iface);
    $config = '/etc/sysconfig/network/ifcfg-tunl1';
    $self->get_from_data('wicked/ifcfg-tunl1_', $config, add_suffix => 1);
    $self->setup_tunnel($config, "tunl1");
    $results{3} = $self->get_test_result("tunl1", "");
    mutex_create("test_6_ready");
    assert_script_run("ifdown tunl1");
    assert_script_run("rm $config");

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
