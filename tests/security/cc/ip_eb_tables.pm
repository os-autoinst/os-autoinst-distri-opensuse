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
    my ($self)          = shift;
    my $f_ifcfg_br0     = '/etc/sysconfig/network/ifcfg-br0';
    my $f_ifcfg_eth0    = '/etc/sysconfig/network/ifcfg-eth0';
    my $bakf_ifcfg_eth0 = '/etc/sysconfig/network/ifcfg-eth0.bak';
    my $br0_config      = "BOOTPROTO='dhcp'\nSTARTMODE='auto'\nBRIDGE='yes'\nBRIDGE_PORTS='eth0'\nBRIDGE_STP='off'\nBRIDGE_FORWARDDELAY='15'\n";
    my $eth0_config     = "IPADDR='0.0.0.0'\nBOOTPROTO='none'\nSTARTMODE='auto'\n";

    select_console 'root-console';

    # Configure bridge for ip_eb_tables workaround
    assert_script_run("cat > $f_ifcfg_br0 <<'END'\n$br0_config\nEND\n( exit \$?)");

    # Creating backup for eth0 configuration
    assert_script_run("cp $f_ifcfg_eth0 $bakf_ifcfg_eth0");

    # Configure eth0 for ip_eb_tables workaround
    assert_script_run("cat > $f_ifcfg_eth0 <<'END'\n$eth0_config\nEND\n( exit \$?)");

    assert_script_run("service network restart");
    assert_script_run("bridge link show");

    # Run test case
    run_testcase('ip+eb-tables', timeout => 300);

    # Clean-up and restore configuration
    assert_script_run("rm $f_ifcfg_br0");
    assert_script_run("rm $f_ifcfg_eth0");
    assert_script_run("cp $bakf_ifcfg_eth0 $f_ifcfg_eth0");
    assert_script_run("service network restart");

    # Compare current test results with baseline
    my $result = compare_run_log('ip_eb_tables');
    $self->result($result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
