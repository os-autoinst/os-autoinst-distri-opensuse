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
use sles4sap::sap_deployment_automation_framework::deployment
  qw(serial_console_diag_banner load_os_env_variables prepare_tfvars_file sdaf_execute_deployment az_login);
use sles4sap::sap_deployment_automation_framework::naming_conventions
  qw(generate_resource_group_name get_sdaf_config_path convert_region_to_short);
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    serial_console_diag_banner('Module sdaf_deploy_sap_systems.pm : start');
    select_serial_terminal();
    my $env_code = get_required_var('SDAF_ENV_CODE');
    my $sap_sid = get_required_var('SAP_SID');
    my $workload_vnet_code = get_required_var('SDAF_WORKLOAD_VNET_CODE');
    my $sdaf_region_code = convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));

    # SAP systems use same VNET as workload zone
    set_var('SDAF_VNET_CODE', $workload_vnet_code);
    # Setup Workload zone openQA variables - used for tfvars template
    set_var('SDAF_RESOURCE_GROUP', generate_resource_group_name(deployment_type => 'sap_system'));

    # From now on everything is executed on Deployer VM (residing on cloud).
    connect_target_to_serial();
    load_os_env_variables();

    prepare_tfvars_file(deployment_type => 'sap_system');

    # Custom VM sizing since default VMs are way too large for functional testing
    # Check for details: https://learn.microsoft.com/en-us/azure/sap/automation/configure-extra-disks#custom-sizing-file
    my $custom_sizes_target_path = get_sdaf_config_path(
        deployment_type => 'sap_system',
        vnet_code => $workload_vnet_code,
        sap_sid => $sap_sid,
        sdaf_region_code => $sdaf_region_code,
        env_code => $env_code);

    my $retrieve_custom_sizing = join(' ', 'curl', '-v', '-fL',
        data_url('sles4sap/sap_deployment_automation_framework/custom_sizes.json'),
        '-o', $custom_sizes_target_path . '/custom_sizes.json');

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
