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
# Test 1 : Create a gre interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';

sub run {
    my ($self) = @_;
    record_info('Test 1', 'Create a gre interface from legacy ifcfg files');
    my $is_wicked_ref = check_var('IS_WICKED_REF', 1);
    $self->setup_static_network($self->get_ip(is_wicked_ref => $is_wicked_ref));
    my $gre_config = '/etc/sysconfig/network/ifcfg-gre1';
    $self->get_from_data('wicked/ifcfg-gre1_', $gre_config, add_suffix => 1);
    my $ip_no_mask               = $self->get_ip(no_mask => 1, is_wicked_ref => $is_wicked_ref);
    my $parallel_host_ip_no_mask = $self->get_ip(no_mask => 1, is_wicked_ref => !$is_wicked_ref);
    my $ip_in_tunnel          = $is_wicked_ref  ? "192.168.1.1" : "192.168.1.2";
    my $parallel_ip_in_tunnel = !$is_wicked_ref ? "192.168.1.1" : "192.168.1.2";
    assert_script_run("echo  \"\nTUNNEL_LOCAL_IPADDR=\'$ip_no_mask\'\" >> $gre_config");
    assert_script_run("echo  \"\nTUNNEL_REMOTE_IPADDR=\'$parallel_host_ip_no_mask\'\" >> $gre_config");
    assert_script_run("echo  \"\nIPADDR=\'$ip_in_tunnel/24\'\" >> $gre_config");
    assert_script_run("cat $gre_config");
    assert_script_run('ifup gre1');
    assert_script_run("ping -c1 $parallel_ip_in_tunnel");
}

1;
