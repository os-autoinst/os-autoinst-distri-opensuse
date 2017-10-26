# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
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

use base "consoletest";
use strict;
use testapi;
use utils qw(systemctl snapper_revert_system);


sub run {
    my ($self) = @_;
    type_string("#***Test 1: Create a gre interface from legacy ifcfg files***\n");
    # different ips for SUT and REF instances of test
    my $ip = check_var('IS_WICKED_REF', '1') ? '10.0.2.10/15' : '10.0.2.11/15';
    $self->setup_static_network($ip);
    my $snapshot_number = script_output('echo $clean_system');
    set_var('BTRFS_SNAPSHOT_NUMBER', $snapshot_number);
    my $config_name = 'wicked/ifcfg-gre1_';
    $config_name .= check_var('IS_WICKED_REF', '1') ? 'ref' : 'sut';
    assert_script_run("wget --quiet " . data_url($config_name) . " -O /etc/sysconfig/network/ifcfg-gre1");
    my $ip_no_mask = '';
    $ip_no_mask = $1 if $ip =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/;
    assert_script_run("echo  \"IPADDR=\'" . $ip_no_mask . "\'\" >> /etc/sysconfig/network/ifcfg-gre1");
    assert_script_run('cat /etc/sysconfig/network/ifcfg-gre1');
    assert_script_run('ifup gre1');
    assert_script_run("ip -4 route add $ip_no_mask dev gre1");
    assert_script_run('ip -6 route add $(sed -n "s/^IPADDR6=\'\(.*\)\'/\1/p" /etc/sysconfig/network/ifcfg-gre1) dev gre1');
    assert_script_run('ip route');
}

1;
