# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'ip+eb-tables' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#96049

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;
    my $f_ifcfg_br0 = '/etc/sysconfig/network/ifcfg-br0';
    my $f_ifcfg_eth0 = '/etc/sysconfig/network/ifcfg-eth0';
    my $bakf_ifcfg_eth0 = '/etc/sysconfig/network/ifcfg-eth0.bak';
    my $br0_config = "BOOTPROTO='dhcp'\nSTARTMODE='auto'\nBRIDGE='yes'\nBRIDGE_PORTS='eth0'\nBRIDGE_STP='off'\nBRIDGE_FORWARDDELAY='15'\n";
    my $eth0_config = "IPADDR='0.0.0.0'\nBOOTPROTO='none'\nSTARTMODE='auto'\n";

    select_console 'root-console';

    # Audit ebtables tests need bridge network. When system role is CC, the bridge is set up
    # automatically in x86 and arm, so we only need to configure the bridge network for s390x
    if (is_s390x) {
        # Configure bridge for ip_eb_tables workaround
        assert_script_run("cat > $f_ifcfg_br0 <<'END'\n$br0_config\nEND\n( exit \$?)");

        # Creating backup for eth0 configuration
        assert_script_run("cp $f_ifcfg_eth0 $bakf_ifcfg_eth0");

        # Configure eth0 for ip_eb_tables workaround
        assert_script_run("cat > $f_ifcfg_eth0 <<'END'\n$eth0_config\nEND\n( exit \$?)");

        assert_script_run("service network restart");
        assert_script_run("bridge link show");
    }

    record_info('Bridge network', 'bsc#1190475');
    # Run test case
    run_testcase('ip+eb-tables', timeout => 300);

    if (is_s390x) {
        # Clean-up and restore configuration
        assert_script_run("rm $f_ifcfg_br0");
        assert_script_run("rm $f_ifcfg_eth0");
        assert_script_run("cp $bakf_ifcfg_eth0 $f_ifcfg_eth0");
        assert_script_run("service network restart");
    }
    # Compare current test results with baseline
    my $result = compare_run_log('ip+eb-tables');
    $self->result($result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
