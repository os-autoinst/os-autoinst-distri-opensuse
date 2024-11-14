# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executes setup of HanaSR scenario using SDAF ansible playbooks according to:
#           https://learn.microsoft.com/en-us/azure/sap/automation/tutorial#sap-application-installation
# Playbooks can be found in SDAF repo: https://github.com/Azure/sap-automation/tree/main/deploy/ansible

# Required OpenQA variables:
#     'SDAF_ENV_CODE'  Code for SDAF deployment env.
#     'PUBLIC_CLOUD_REGION' SDAF internal code for azure region.
#     'SAP_SID' SAP system ID.
#     'SDAF_DEPLOYER_RESOURCE_GROUP' Existing deployer resource group - part of the permanent cloud infrastructure.

# Optional:
#     'SDAF_ANSIBLE_VERBOSITY_LEVEL' Override default verbosity for 'ansible-playbook'.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment
  qw(serial_console_diag_banner
  load_os_env_variables
  az_login
  sdaf_execute_playbook
  ansible_hanasr_show_status
  );
use sles4sap::sap_deployment_automation_framework::naming_conventions
  qw(get_sdaf_config_path convert_region_to_short get_workload_vnet_code);
use sles4sap::console_redirection
  qw(connect_target_to_serial
  disconnect_target_from_serial
  );
use serial_terminal qw(select_serial_terminal);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    serial_console_diag_banner('Module sdaf_deploy_hanasr.pm : start');
    my $sdaf_config_root_dir = get_sdaf_config_path(
        deployment_type => 'sap_system',
        vnet_code => get_workload_vnet_code(),
        env_code => get_required_var('SDAF_ENV_CODE'),
        sdaf_region_code => convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION')),
        sap_sid => get_required_var('SAP_SID')
    );

    # List of playbooks (and their options) to be executed. Keep them in list to be ordered. Each entry must be an ARRAYREF.
    # Playbook description is here as well: https://learn.microsoft.com/en-us/azure/sap/automation/run-ansible?tabs=linux
    my @execute_playbooks = (
        # Fetches SSH key from Workload zone keyvault for accesssing SUTs
        {playbook_filename => 'pb_get-sshkey.yaml', timeout => 90},
        # Validate parameters
        {playbook_filename => 'playbook_00_validate_parameters.yaml', timeout => 120},
        # Base operating system configuration
        {playbook_filename => 'playbook_01_os_base_config.yaml'},
        # SAP-specific operating system configuration
        {playbook_filename => 'playbook_02_os_sap_specific_config.yaml'},
        # SAP Bill of Materials processing - this also mounts install media storage
        {playbook_filename => 'playbook_03_bom_processing.yaml'},
        # SAP HANA database installation
        {playbook_filename => 'playbook_04_00_00_db_install.yaml', timeout => 180},
        # SAP HANA high-availability configuration
        {playbook_filename => 'playbook_04_00_01_db_ha.yaml', timeout => 1800},
    );

    connect_target_to_serial();
    load_os_env_variables();
    # Some playbooks use azure cli
    az_login();

    for my $playbook_options (@execute_playbooks) {
        # Package 'fence-agents-azure-arm' is not yet installed by SDAF, therefore a workaround has to be applied
        if ($playbook_options->{playbook_filename} eq 'playbook_04_00_00_db_install.yaml') {
            record_soft_failure("bsc#1226671 - New package 'fence-agents-azure=arm' has to be installed to prevent HA setup failure");
            my @cmd = ('ansible', 'QES_DB',
                "--private-key=$sdaf_config_root_dir/sshkey",
                '--inventory=' . get_required_var('SAP_SID') . '_hosts.yaml',
                '--module-name=shell',
                '--args="sudo zypper in -y fence-agents-azure-arm"');
            assert_script_run(join(' ', @cmd));
        }
        sdaf_execute_playbook(%{$playbook_options}, sdaf_config_root_dir => $sdaf_config_root_dir);
    }

    # Display deployment information
    ansible_hanasr_show_status(sdaf_config_root_dir => $sdaf_config_root_dir);

    disconnect_target_from_serial();
    serial_console_diag_banner('Module sdaf_deploy_hanasr.pm : stop');
}

1;
