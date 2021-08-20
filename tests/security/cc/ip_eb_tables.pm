# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'ip+eb-tables' test case of 'audit-test' test suite
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#96049

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    #Configure bridge for ip_eb_tables workaround
    assert_script_run("echo \"BOOTPROTO='dhcp'\" > /etc/sysconfig/network/ifcfg-br0");
    assert_script_run("echo \"STARTMODE='auto'\" >> /etc/sysconfig/network/ifcfg-br0");
    assert_script_run("echo \"BRIDGE='yes'\" >> /etc/sysconfig/network/ifcfg-br0");
    assert_script_run("echo \"BRIDGE_PORTS='eth0'\" >> /etc/sysconfig/network/ifcfg-br0");
    assert_script_run("echo \"BRIDGE_STP='off'\" >> /etc/sysconfig/network/ifcfg-br0");
    assert_script_run("echo \"BRIDGE_FORWARDDELAY='15'\" >> /etc/sysconfig/network/ifcfg-br0");
    
    # Backup eth0 configuration
    assert_script_run("cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth0.bak");

    # eth0 coniguration
    assert_script_run("echo \"IPADDR='0.0.0.0'\" > /etc/sysconfig/network/ifcfg-eth0");
    assert_script_run("echo \"BOOTPROTO='none'\" >> /etc/sysconfig/network/ifcfg-eth0");
    assert_script_run("echo \"STARTMODE='auto'\" >> /etc/sysconfig/network/ifcfg-eth0");

    assert_script_run("service network restart");
    assert_script_run("bridge link show");

    # Run test case
    run_testcase('ip+eb-tables', timeout => 300);

    # Restore eth0 configuration
    assert_script_run("rm /etc/sysconfig/network/ifcfg-br0");
    assert_script_run("rm /etc/sysconfig/network/ifcfg-eth0");
    assert_script_run("cp /etc/sysconfig/network/ifcfg-eth0.bak /etc/sysconfig/network/ifcfg-eth0");
    assert_script_run("service network restart");

    # Compare current test results with baseline
    my $result = compare_run_log('ip_eb_tables');
    $self->result($result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
