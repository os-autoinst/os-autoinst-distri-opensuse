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
use sles4sap::sap_deployment_automation_framework::deployment
  qw(serial_console_diag_banner
  az_login
  sdaf_prepare_ssh_keys
  );
use sles4sap::sap_deployment_automation_framework::deployment_connector
  qw(get_deployer_vm
  get_deployer_ip
  );
use sles4sap::console_redirection qw(redirection_init);
use serial_terminal qw(select_serial_terminal);

sub test_flags {
    return {fatal => 1};
}
sub run {
    select_serial_terminal();
    serial_console_diag_banner('Module sdaf_redirect_console_to_deployer.pm : start');
    az_login();

    my $deployer_vm_name = get_deployer_vm;
    # VM can be created by scheduling 'tests/sles4sap/sap_deployment_automation_framework/create_deployer_vm.pm'
    die 'Deployer VM not found. Check if VM exists.' unless $deployer_vm_name;
    record_info('VM found', "Deployer VM found: $deployer_vm_name");

    my $deployer_ip = get_deployer_ip(deployer_vm_name => $deployer_vm_name);
    # SDAF does not need privileged user to run.
    my $ssh_user = get_var('REDIRECT_TARGET_USER', 'azureadm');
    # Variables to share data between test modules.
    set_var('REDIRECT_DESTINATION_USER', $ssh_user);
    set_var('REDIRECT_DESTINATION_IP', $deployer_ip);    # IP addr to redirect console to
    sdaf_prepare_ssh_keys(deployer_key_vault => get_required_var('SDAF_KEY_VAULT'));

    # autossh is required for console redirection to work
    assert_script_run('zypper in -y autossh');
    redirection_init();
    serial_console_diag_banner('Module sdaf_redirect_console_to_deployer.pm : end');
}

1;
