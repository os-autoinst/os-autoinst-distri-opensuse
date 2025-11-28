# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test initializes console redirection to cloud Deployer VM.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use testapi;
use sles4sap::sap_deployment_automation_framework::deployment
  qw(serial_console_diag_banner az_login sdaf_ssh_key_from_keyvault);
use sles4sap::sap_deployment_automation_framework::deployment_connector
  qw(get_deployer_vm_name get_deployer_ip find_deployment_id);
use sles4sap::sap_deployment_automation_framework::naming_conventions qw($deployer_private_key_path);
use serial_terminal qw(select_serial_terminal);

sub test_flags {
    return {fatal => 1};
}
sub run {
    select_serial_terminal();
    serial_console_diag_banner('Module sdaf_redirect_console_to_deployer.pm : start');
    az_login();

    my $deployer_vm_name = get_deployer_vm_name(deployment_id => find_deployment_id());
    # VM can be created by scheduling 'tests/sles4sap/sap_deployment_automation_framework/create_deployer_vm.pm'
    die 'Deployer VM not found. Check if VM exists.' unless $deployer_vm_name;
    record_info('VM found', "Deployer VM found: $deployer_vm_name");

    # Variables to share data between test modules.
    my $deployer_ip = get_deployer_ip(deployer_vm_name => $deployer_vm_name);
    # This will allow using connect_target_to_serial() without specifying user/host to deployer every time.
    set_var('REDIRECT_DESTINATION_USER', get_var('PUBLIC_CLOUD_USER', 'azureadm'));
    set_var('REDIRECT_DESTINATION_IP', $deployer_ip);    # IP addr to redirect console to
    sdaf_ssh_key_from_keyvault(
        key_vault => get_required_var('SDAF_DEPLOYER_KEY_VAULT'), target_file => $deployer_private_key_path);
    serial_console_diag_banner('Module sdaf_redirect_console_to_deployer.pm : end');
}

1;
