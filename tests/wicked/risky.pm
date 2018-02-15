# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test scenarios:
# Test 1 : Create a gre interface from legacy ifcfg files
# Summary: Collection of wicked tests which might be hard to implement in
# openQA. Used as POC for wicked testing. Later will be reorganized in other
# test suites.
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';

sub run {
    my ($self) = @_;
    record_info('Test 1', 'Create a gre interface from legacy ifcfg files');
    $self->setup_static_network($self->get_ip());
    my $network_config = '/etc/sysconfig/network/ifcfg-gre1';
    $self->get_from_data('wicked/ifcfg-gre1_', $network_config, add_suffix => 1);
    my $ip_no_mask = '';
    $ip_no_mask = $1 if $self->get_ip() =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/;
    assert_script_run("echo  \"IPADDR=\'$ip_no_mask\'\" >> $network_config");
    assert_script_run("cat $network_config");
    assert_script_run('ifup gre1');
    assert_script_run("ip -4 route add $ip_no_mask dev gre1");
    assert_script_run('ip -6 route add $(sed -n "s/^IPADDR6=\'\(.*\)\'/\1/p" ' . $network_config . ') dev gre1');
    assert_script_run('ip route');
}

1;
