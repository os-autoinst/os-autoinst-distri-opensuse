# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Basetest used for Microsoft SDAF deployment

package sles4sap::sap_deployment_automation_framework::basetest;
use strict;
use warnings;
use testapi;
use parent 'opensusebasetest';
use sles4sap::sap_deployment_automation_framework::deployment qw(sdaf_cleanup az_login load_os_env_variables);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployer_resources destroy_deployer_vm);
use sles4sap::console_redirection qw(connect_target_to_serial disconnect_target_from_serial);

sub post_fail_hook {
    if (get_var('SDAF_RETAIN_DEPLOYMENT')) {
        record_info('Cleanup OFF', 'OpenQA variable "SDAF_RETAIN_DEPLOYMENT" is active, skipping cleanup.');
        return;
    }
    record_info('Post fail', 'Executing post fail hook');

    # Do not attempt to access deployer if redirection was not set up yet.
    record_info('SUT cleanup', 'Redirection seems not being set up, skipping sdaf cleanup scripts.')
      unless get_var('REDIRECTION_CONFIGURED');
    if (get_var('REDIRECTION_CONFIGURED')) {
        # Trigger SDAF remover script to destroy 'workload zone' and 'sap systems' resources
        # Clean up all config files, keys, etc.. on deployer VM
        connect_target_to_serial();
        load_os_env_variables();
        az_login();
        sdaf_cleanup();
        disconnect_target_from_serial();
    }
    # Destroys deployer VM and its resources
    destroy_deployer_vm();
}

1;
