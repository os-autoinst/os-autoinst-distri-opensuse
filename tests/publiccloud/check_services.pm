# SUSE's openQA tests
#
# Copyright 2024 - 2025 SUSE LLC
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

    my $instance = $args->{my_instance};

    # Debug
    $instance->ssh_script_run('systemctl --no-pager list-units');

    # waagent, cloud-init, google agents not available in Micro
    unless (is_sle_micro) {
        if (is_azure) {
            # waagent (Azure Linux VM Agent)
            record_info('waagent', $instance->ssh_script_output('systemctl --no-pager --full status waagent*', proceed_on_failure => 1));
            $instance->ssh_assert_script_run('systemctl is-active waagent.service');
            $instance->ssh_assert_script_run('systemctl is-enabled waagent-network-setup.service');
        }
        if ((is_azure || is_ec2) && !is_container_host()) {
            # cloud-init
            record_info('cloud-init', $instance->ssh_script_output('systemctl --no-pager --full status cloud-init*', proceed_on_failure => 1));
            $instance->ssh_assert_script_run('systemctl is-active cloud-init.service');
            $instance->ssh_assert_script_run('systemctl is-active cloud-init.target');
            $instance->ssh_assert_script_run('systemctl is-active cloud-init-local.service');
            # cloud-config
            record_info('cloud-config', $instance->ssh_script_output('systemctl --no-pager --full status cloud-config*', proceed_on_failure => 1));
            $instance->ssh_assert_script_run('systemctl is-active cloud-config.service');
            $instance->ssh_assert_script_run('systemctl is-active cloud-config.target');
        }
        if (is_gce) {
            # google-guest-agent & google-osconfig-agent
            record_info('google', $instance->ssh_script_output('systemctl --no-pager --full status google*', proceed_on_failure => 1));
            $instance->ssh_assert_script_run('systemctl is-active google-guest-agent.service');
            $instance->ssh_assert_script_run('systemctl is-active google-osconfig-agent.service');
            $instance->ssh_assert_script_run('systemctl is-active google-oslogin-cache.timer');
            # Wait until google-startup-scripts.service is inactive (exited) with status=0/SUCCESS
            $instance->ssh_script_retry('! systemctl is-active google-startup-scripts.service', retry => 3, delay => 5);
            $instance->ssh_assert_script_run('! systemctl is-failed google-startup-scripts.service');
            # Check that google-shutdown-scripts.service is active (exited)
            $instance->ssh_assert_script_run('systemctl is-active google-shutdown-scripts.service');
        }
    }
    # cloud-netconfig
    # in GCE from 15-SP4 (see bsc#1227507, bsc#1227508)
    unless ((is_sle('<15-SP4') && is_gce) || is_container_host) {
        record_info('cloud-netconfig', $instance->ssh_script_output('systemctl --no-pager --full status cloud-netconfig*', proceed_on_failure => 1));
        $instance->ssh_assert_script_run('systemctl is-enabled cloud-netconfig.service');
        $instance->ssh_assert_script_run('systemctl is-active cloud-netconfig.timer');
    }
}

sub test_flags {
    return {fatal => 0, publiccloud_multi_module => 1};
}

1;
