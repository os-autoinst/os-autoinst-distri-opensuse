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
# Maintainers:
#     Anton Smorodskyi <asmorodskyi@suse.com>
#     Jose Lausuch <jalausuch@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use lockapi;
use mmapi;

sub run {
    my ($self) = @_;
    record_info('Test 1', 'Create a gre interface from legacy ifcfg files');
    my $gre_config = '/etc/sysconfig/network/ifcfg-gre1';
    $self->get_from_data('wicked/ifcfg-gre1_', $gre_config, add_suffix => 1);
    my $ip_no_mask               = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    my $parallel_host_ip_no_mask = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    my $ip_in_tunnel          = $self->get_ip(is_wicked_ref => 0, type => 'gre_tunnel_ip');
    my $parallel_ip_in_tunnel = $self->get_ip(is_wicked_ref => 1, type => 'gre_tunnel_ip');
    assert_script_run("sed \'s/local_ip/$ip_no_mask/\' -i $gre_config");
    assert_script_run("sed \'s/remote_ip/$parallel_host_ip_no_mask/\' -i $gre_config");
    assert_script_run("sed \'s/tunnel_ip/$ip_in_tunnel\\/24/\' -i $gre_config");
    assert_script_run("cat $gre_config");
    assert_script_run('ifup gre1');
    assert_script_run('ip a');
    my $ret = $self->ping_with_timeout(ip => "$parallel_ip_in_tunnel", timeout => '60');
    # Create mutex to unlock REF
    mutex_create("test_1_ready");
    wait_for_children;
    record_info("[Test 1] Can't ping IP $parallel_ip_in_tunnel") if !$ret;
    #TODO: Reset network (delete gre1 interface)

    record_info('Test 3', 'Create a SIT interface from legacy ifcfg files');
    my $sit_config = '/etc/sysconfig/network/ifcfg-sit1';
    $self->get_from_data('wicked/ifcfg-sit1_', $sit_config, add_suffix => 1);
    my $ip_in_tunnel          = $self->get_ip(is_wicked_ref => 0, type => 'sit_tunnel_ip');
    my $parallel_ip_in_tunnel = $self->get_ip(is_wicked_ref => 1, type => 'sit_tunnel_ip');
    assert_script_run("sed \'s/local_ip/$ip_no_mask/\' -i $sit_config");
    assert_script_run("sed \'s/remote_ip/$parallel_host_ip_no_mask/\' -i $sit_config");
    assert_script_run("sed \'s/tunnel_ip/$ip_in_tunnel\\/127/\' -i $sit_config");
    assert_script_run("cat $sit_config");
    assert_script_run('ifup sit1');
    assert_script_run('ip a');
    $ret = $self->ping_with_timeout(ip => "$parallel_ip_in_tunnel", timeout => '60', ip_version => 'v6');
    # Create mutex to unlock REF
    mutex_create("test_3_ready");
    record_info("[Test 3] Can't ping IP $parallel_ip_in_tunnel") if !$ret;
    #TODO: Reset network (delete sit1 interface)
}

1;

