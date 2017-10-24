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
    my ($self)   = @_;
    my $gre_ipv4 = '';
    my $gre_ipv6 = '';
    type_string("#***Test 1: Create a gre interface from legacy ifcfg files***\n");
    if (check_var('WICKED', 'RISKY_REF')) {
        $gre_ipv4 = '10.0.2.10';
        $gre_ipv6 = 'fd00:222::123/128';
        assert_script_run "wget --quiet " . data_url('wicked/ifcfg-gre1_ref') . " -O /etc/sysconfig/network/ifcfg-gre1";
    }
    elsif (check_var('WICKED', 'RISKY_SUT')) {
        $gre_ipv4 = '10.0.2.11';
        $gre_ipv6 = 'fd00:222::1';
        assert_script_run "wget --quiet " . data_url('wicked/ifcfg-gre1_sut') . " -O /etc/sysconfig/network/ifcfg-gre1";
    }
    assert_script_run "ifup gre1";
    assert_script_run "ip -4 route add $gre_ipv4  dev gre1";
    assert_script_run "ip -6 route add  $gre_ipv6 dev gre1";
    assert_script_run "ip route";
}

1;
