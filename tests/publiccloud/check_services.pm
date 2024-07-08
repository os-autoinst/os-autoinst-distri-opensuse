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

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    # Debug
    script_run('systemctl --no-pager list-units');

    # waagent
    if (is_azure) {
        record_info('waagent', script_output('systemctl --no-pager --full status waagent*', proceed_on_failure => 1));
        assert_script_run('systemctl is-active waagent.service');
        assert_script_run('systemctl is-enabled waagent-network-setup.service');
    }

    # cloud-init
    if (is_azure || is_ec2) {
        record_info('cloud-init', script_output('systemctl --no-pager --full status cloud-init*', proceed_on_failure => 1));
        assert_script_run('systemctl is-active cloud-init.service');
        assert_script_run('systemctl is-active cloud-init.target');
        assert_script_run('systemctl is-active cloud-init-local.service');
    }

    # cloud-config
    if (is_azure || is_ec2) {
        record_info('cloud-config', script_output('systemctl --no-pager --full status cloud-config*', proceed_on_failure => 1));
        assert_script_run('systemctl is-active cloud-config.service');
        assert_script_run('systemctl is-active cloud-config.target');
    }

    # google-guest-agent & google-osconfig-agent
    if (is_gce) {
        record_info('google', script_output('systemctl --no-pager --full status google*', proceed_on_failure => 1));
        assert_script_run('systemctl is-active google-guest-agent.service');
        assert_script_run('systemctl is-active google-osconfig-agent.service');
        assert_script_run('systemctl is-active google-shutdown-scripts.service');
        assert_script_run('systemctl is-active google-oslogin-cache.timer');
    }

    # cloud-netconfig
    if ((is_sle('=12-SP5') || is_sle('=15-SP3')) && is_gce) {
        record_soft_failure('bsc#1227507 - 12-SP5 images are missing cloud-netconfig.service/timer');
        record_soft_failure('bsc#1227508 - 15-SP3 images are missing cloud-netconfig.service/timer');
    } else {
        record_info('cloud-netconfig', script_output('systemctl --no-pager --full status cloud-netconfig*', proceed_on_failure => 1));
        assert_script_run('systemctl is-enabled cloud-netconfig.service');
        assert_script_run('systemctl is-active cloud-netconfig.timer');
    }
}

sub test_flags {
    return {fatal => 0, publiccloud_multi_module => 1};
}

1;
