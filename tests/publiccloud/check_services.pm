# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check public cloud specific services
# Maintainer: qa-c <qa-c@suse.de>

use base 'publiccloud::basetest';
use serial_terminal 'select_serial_terminal';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use version_utils;
use publiccloud::utils;
use publiccloud::ssh_interactive 'select_host_console';

sub run {
    my ($self, $args) = @_;
    select_host_console();

    my $instance = $self->{my_instance} = $args->{my_instance};
    my $provider = $self->{provider} = $args->{my_provider};    # required for cleanup

    # Debug
    $instance->ssh_script_run('systemctl --no-pager list-units');

    # waagent (Azure Linux VM Agent)
    # waagent is not available in Micro
    if (is_azure && !is_sle_micro) {
        record_info('waagent', $instance->ssh_script_output('systemctl --no-pager --full status waagent*', proceed_on_failure => 1));
        $instance->ssh_assert_script_run('systemctl is-active waagent.service');
        $instance->ssh_assert_script_run('systemctl is-enabled waagent-network-setup.service');
    }

    # cloud-init
    # cloud-init is notavailable in Micro
    if ((is_azure || is_ec2) && !is_sle_micro) {
        record_info('cloud-init', $instance->ssh_script_output('systemctl --no-pager --full status cloud-init*', proceed_on_failure => 1));
        $instance->ssh_assert_script_run('systemctl is-active cloud-init.service');
        $instance->ssh_assert_script_run('systemctl is-active cloud-init.target');
        $instance->ssh_assert_script_run('systemctl is-active cloud-init-local.service');
    }

    # cloud-config
    if ((is_azure || is_ec2) && !is_sle_micro) {
        record_info('cloud-config', $instance->ssh_script_output('systemctl --no-pager --full status cloud-config*', proceed_on_failure => 1));
        $instance->ssh_assert_script_run('systemctl is-active cloud-config.service');
        $instance->ssh_assert_script_run('systemctl is-active cloud-config.target');
    }

    # google-guest-agent & google-osconfig-agent
    # google agents are not available in Micro
    if (is_gce && !is_sle_micro) {
        record_info('google', $instance->ssh_script_output('systemctl --no-pager --full status google*', proceed_on_failure => 1));
        $instance->ssh_assert_script_run('systemctl is-active google-guest-agent.service');
        $instance->ssh_assert_script_run('systemctl is-active google-osconfig-agent.service');
        $instance->ssh_assert_script_run('systemctl is-active google-shutdown-scripts.service');
        $instance->ssh_assert_script_run('systemctl is-active google-oslogin-cache.timer');
    }

    # cloud-netconfig
    # in GCE from 15-SP4 (see bsc#1227507, bsc#1227508)
    unless (is_sle('<15-SP4') && is_gce) {
        record_info('cloud-netconfig', $instance->ssh_script_output('systemctl --no-pager --full status cloud-netconfig*', proceed_on_failure => 1));
        $instance->ssh_assert_script_run('systemctl is-enabled cloud-netconfig.service');
        $instance->ssh_assert_script_run('systemctl is-active cloud-netconfig.timer');
    }
}

sub test_flags {
    return {fatal => 0, publiccloud_multi_module => 1};
}

1;
