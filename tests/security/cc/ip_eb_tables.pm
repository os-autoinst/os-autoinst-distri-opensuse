# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'ip+eb-tables' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#96049

use Mojo::Base 'consoletest';
use testapi;
use utils;
use Utils::Architectures 'is_s390x';
use version_utils 'is_sle';
use audit_test qw(run_testcase compare_run_log);
use network_utils 'iface';

sub setup_bridge {
    my $eth = iface();
    my $f_ifcfg_br0 = '/etc/sysconfig/network/ifcfg-br0';
    my $f_ifcfg_eth = "/etc/sysconfig/network/ifcfg-$eth";
    my $bakf_ifcfg_eth = "/etc/sysconfig/network/ifcfg-$eth.bak";
    my $br0_config = "BOOTPROTO='dhcp'\nSTARTMODE='auto'\nBRIDGE='yes'\nBRIDGE_PORTS='$eth'\nBRIDGE_STP='off'\nBRIDGE_FORWARDDELAY='15'\n";
    my $eth_config = "IPADDR='0.0.0.0'\nBOOTPROTO='none'\nSTARTMODE='auto'\n";

    # Configure bridge for ip_eb_tables workaround
    assert_script_run("cat > $f_ifcfg_br0 <<'END'\n$br0_config\nEND\n( exit \$?)");

    # Creating backup for network interface configuration
    assert_script_run("cp $f_ifcfg_eth $bakf_ifcfg_eth");

    # Configure network interface for ip_eb_tables workaround
    assert_script_run("cat > $f_ifcfg_eth <<'END'\n$eth_config\nEND\n( exit \$?)");

    assert_script_run("service network restart");
    assert_script_run("bridge link show");
}

sub cleanup_bridge {
    my $eth = iface();
    my $f_ifcfg_br0 = '/etc/sysconfig/network/ifcfg-br0';
    my $f_ifcfg_eth = "/etc/sysconfig/network/ifcfg-$eth";
    my $bakf_ifcfg_eth = "/etc/sysconfig/network/ifcfg-$eth.bak";

    # Clean-up and restore configuration
    assert_script_run("rm -f $f_ifcfg_br0");
    assert_script_run("rm -f $f_ifcfg_eth");
    assert_script_run("cp $bakf_ifcfg_eth $f_ifcfg_eth");
    assert_script_run("rm -f $bakf_ifcfg_eth");
    assert_script_run("service network restart");
}

sub run {
    my ($self) = shift;

    if (is_sle('>=15-SP6') && is_s390x) {
        record_soft_failure('SKIPPING TEST - bsc#1242131');
        return;
    }

    select_console 'root-console';

    # Audit ebtables tests need bridge network. When system role is CC, the bridge is set up
    # automatically in x86 and arm, so we only need to configure the bridge network for s390x
    $self->setup_bridge if is_s390x;

    record_info('Bridge network', 'bsc#1190475');
    # Run test case
    run_testcase('ip+eb-tables', timeout => 300);

    $self->cleanup_bridge if is_s390x;

    # Compare current test results with baseline
    my $result = compare_run_log('ip+eb-tables');
    $self->result($result);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->cleanup_bridge if is_s390x;
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {always_rollback => 1};
}

1;
