# SUSE's openQA tests
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: YaST writes config to 70-yast.conf and detects conflicts
# - Install yast2-network
# - verify writing config to the correct file
# - ensure conflict detected when custom config with higher priority exists
# - validate that YaST applies changes to the system. bsc#1167234
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use y2lan_restart_common;

my $yastconf = '/etc/sysctl.d/70-yast.conf';
my $customconf_in_etc = '/etc/sysctl.d/90-custom.conf';
my $customconf_in_usr_lib = '/usr/lib/sysctl.d/90-custom.conf';
my $ipv4_forward = 'net.ipv4.ip_forward';

sub verify_write_config {
    change_ipforward(state => 'enabled', should_conflict => 0);
}

sub ensure_conflict_detected {
    _create_conflicts();
    change_ipforward(state => 'disabled', should_conflict => 1);
    # Log trace for conflict
    validate_script_output "grep 'have conflicts with' /var/log/YaST2/y2log", sub { m%$customconf_in_etc% };
    # No conflict if config is under /usr/lib/
    validate_script_output "grep 'have conflicts with' /var/log/YaST2/y2log", sub { !m%$customconf_in_usr_lib% };
}

sub validate_changes_applied_to_system {
    assert_script_run("grep '$ipv4_forward = 1' $yastconf");
    assert_script_run("sysctl $ipv4_forward | grep 1");
    assert_script_run("cat /proc/sys/net/ipv4/ip_forward | grep 1", fail_message => "ip_forward not applied to system bsc#1167234");
}

sub _create_conflicts {
    # Files with higher priority that 70-yast.conf.
    # But /etc has precedence over /usr/lib, thus second one should not
    # cause conflict
    foreach my $conf ($customconf_in_etc, $customconf_in_usr_lib) {
        assert_script_run("touch $conf");
        my $create_other_conf = "echo $ipv4_forward=1 > $conf && (exit $?)";
        assert_script_run("$create_other_conf", fail_message => "Creating $conf failed.");
        script_run("cat $conf", output => "show output for $conf");
    }
}

sub run {
    my $self = shift;

    select_console 'root-console';
    zypper_call "in yast2-network";    # make sure yast2 routing module installed

    assert_script_run("sysctl net.ipv4.ip_forward | grep 0");
    verify_write_config;
    validate_changes_applied_to_system;
    ensure_conflict_detected;
    # make sure that nothing has changed
    validate_changes_applied_to_system;
    script_run("rm -rf $customconf_in_etc $customconf_in_usr_lib", output => "cleanup test files");
    clear_console;
}

1;
