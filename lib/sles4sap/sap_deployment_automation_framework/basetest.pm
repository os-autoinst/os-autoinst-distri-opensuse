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
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployer_resources);
use sles4sap::console_redirection qw(connect_target_to_serial disconnect_target_from_serial);
use sles4sap::azure_cli qw(az_resource_delete);


sub post_fail_hook {
    if (get_var('SDAF_RETAIN_DEPLOYMENT')) {
        record_info('Cleanup OFF', 'OpenQA variable "SDAF_RETAIN_DEPLOYMENT" is active, skipping cleanup.');
        return;
    }

    record_info('Post fail', 'Executing post fail hook');
    # Trigger SDAF remover script to destroy 'workload zone' and 'sap systems' resources
    # Clean up all config files, keys, etc.. on deployer VM
    connect_target_to_serial();
    load_os_env_variables();
    az_login();
    sdaf_cleanup();
    disconnect_target_from_serial();

    # Cleanup deployer VM resources only
    # Deployer VM is located in permanent deployer resource group. This RG **MUST STAY INTACT**
    my @resource_cleanup_list = @{find_deployer_resources(return_value => 'id')};
    record_info('Resources destroy',
        "Following resources are being destroyed:\n" . join("\n", @{find_deployer_resources()}));

    az_resource_delete(ids => join(' ', @resource_cleanup_list),
        resource_group => get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP'), timeout => '600');
}

1;
