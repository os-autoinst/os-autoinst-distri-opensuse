# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Basetest used for Microsoft SDAF deployment

package sles4sap::sap_deployment_automation_framework::basetest;
use parent 'opensusebasetest';

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use sles4sap::sap_deployment_automation_framework::deployment qw(sdaf_cleanup az_login load_os_env_variables);
use sles4sap::sap_deployment_automation_framework::deployment_connector
  qw(find_deployer_resources destroy_deployer_vm get_deployer_vm_name find_deployment_id get_deployer_ip);
use sles4sap::console_redirection qw(connect_target_to_serial disconnect_target_from_serial check_serial_redirection);

our @EXPORT = qw(full_cleanup);

sub full_cleanup {
    if (get_var('SDAF_RETAIN_DEPLOYMENT')) {
        record_info('Cleanup OFF', 'OpenQA variable "SDAF_RETAIN_DEPLOYMENT" is active, skipping cleanup.');
        return;
    }

    # Disable any redirection being active
    disconnect_target_from_serial if check_serial_redirection();
    az_login();
    # collect required data first. Call functions only if mandatory args are found to avoid triggering croak/die
    my $deployment_id = find_deployment_id();
    my $deployer_vm_name = get_deployer_vm_name(deployment_id => find_deployment_id()) if $deployment_id;
    my $deployer_ip = get_deployer_ip(deployer_vm_name => $deployer_vm_name) if $deployer_vm_name;
    my $redirection_works;

    # Attempt console redirection only if mandatory arguments are defined
    if ($deployer_ip) {
        set_var('REDIRECT_DESTINATION_USER', get_var('PUBLIC_CLOUD_USER', 'azureadm'));
        set_var('REDIRECT_DESTINATION_IP', $deployer_ip);
        # Do not fail even if connection is not successful
        $redirection_works = connect_target_to_serial(fail_ok => '1');
    }

    # First check if redirection works. Skip dependent tasks if it does not
    if ($redirection_works) {
        # Trigger SDAF remover script to destroy 'workload zone' and 'sap systems' resources
        # Clean up all config files, keys, etc.. on deployer VM
        load_os_env_variables();
        az_login();
        sdaf_cleanup();
        disconnect_target_from_serial();
    }
    record_info('SUT cleanup', 'Failed to set up redirection, skipping SDAF cleanup scripts.') unless $redirection_works;

    # Destroys deployer VM and its resources
    destroy_deployer_vm();
}

sub post_fail_hook {
    record_info('Post fail', 'Executing post fail hook');
    full_cleanup();
}

1;
