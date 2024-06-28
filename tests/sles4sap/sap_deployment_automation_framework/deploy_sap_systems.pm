# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deployment of the SAP systems zone using SDAF automation

# Required OpenQA variables:
#     'SDAF_WORKLOAD_VNET_CODE' Virtual network code for workload zone.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    serial_console_diag_banner('Module sdaf_deploy_sap_systems.pm : start');
    select_serial_terminal();

    # From now on everything is executed on Deployer VM (residing on cloud).
    connect_target_to_serial();
    load_os_env_variables();

    # Setup Workload zone openQA variables - used for tfvars template
    set_var('SDAF_RESOURCE_GROUP', generate_resource_group_name(deployment_type => 'sap_system'));
    # SAP systems use same VNET as workload zone
    set_var('SDAF_VNET_CODE', get_required_var('SDAF_WORKLOAD_VNET_CODE'));
    # 'vnet_code' variable changes with deployment type.
    set_os_variable('vnet_code', get_required_var('SDAF_WORKLOAD_VNET_CODE'));
    prepare_tfvars_file(deployment_type => 'sap_system');

    # Custom VM sizing since default VMs are way too large for functional testing
    # Check for details: https://learn.microsoft.com/en-us/azure/sap/automation/configure-extra-disks#custom-sizing-file
    my $retrieve_custom_sizing = join(' ', 'curl', '-v', '-fL',
        data_url('sles4sap/sdaf/custom_sizes.json'),
        '-o', get_os_variable('CONFIG_REPO_PATH') . '/SYSTEM/LAB-SECE-SAP04-QES/custom_sizes.json');
    assert_script_run($retrieve_custom_sizing);

    az_login();
    sdaf_execute_deployment(deployment_type => 'sap_system', timeout => 3600);

    # diconnect the console
    disconnect_target_from_serial();

    # reset temporary variables
    set_var('SDAF_RESOURCE_GROUP', undef);
    set_var('SDAF_VNET_CODE', undef);
    serial_console_diag_banner('Module sdaf_deploy_sap_systems.pm : end');
}

1;
