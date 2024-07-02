# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test initializes console redirection to cloud Deployer VM.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use strict;
use warnings;
use testapi;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);

sub test_flags {
    return {fatal => 1};
}
sub run {

    select_serial_terminal();
    serial_console_diag_banner('Module sdaf_redirect_console_to_deployer.pm : start');

    # autossh is required for console redirection to work
    assert_script_run('zypper in -y autossh');

    az_login();
    my $deployer_ip = sdaf_get_deployer_ip(deployer_resource_group => get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP'));
    # SDAF does not need privileged user to run.
    my $ssh_user = get_var('REDIRECT_TARGET_USER', 'azureadm');
    # Variables to share data between test modules.
    set_var('REDIRECT_DESTINATION_USER', $ssh_user);
    set_var('REDIRECT_DESTINATION_IP', $deployer_ip);    # IP addr to redirect console to
    sdaf_prepare_ssh_keys(deployer_key_vault => get_required_var('SDAF_KEY_VAULT'));

    redirection_init();
    serial_console_diag_banner('Module sdaf_redirect_console_to_deployer.pm : end');
}

1;
