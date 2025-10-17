# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executes setup of HanaSR scenario using SDAF ansible playbooks according to:
#           https://learn.microsoft.com/en-us/azure/sap/automation/tutorial#sap-application-installation

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use sles4sap::azure_cli qw(az_keyvault_list);
use sles4sap::sap_deployment_automation_framework::inventory_tools;
use sles4sap::sap_deployment_automation_framework::deployment qw(sdaf_ssh_key_from_keyvault get_workload_resource_group);
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);

sub run {
    my ($self, $run_args) = @_;
    select_serial_terminal;
    my $env_code = get_required_var('SDAF_ENV_CODE');
    my $sdaf_region_code = convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));
    my $sap_sid = get_required_var('SAP_SID');
    my $workload_vnet_code = get_workload_vnet_code();
    my $workload_rg = get_workload_resource_group(deployment_id => find_deployment_id());
    my $workload_key_vault = ${az_keyvault_list(resource_group => $workload_rg)}[0];

    my $jump_host_user = get_required_var('REDIRECT_DESTINATION_USER');
    my $jump_host_ip = get_required_var('REDIRECT_DESTINATION_IP');
    my $config_root_path = get_sdaf_config_path(deployment_type => 'sap_system', env_code => $env_code,
        sdaf_region_code => $sdaf_region_code, sap_sid => $sap_sid, vnet_code => $workload_vnet_code);
    my $inventory_path = get_sdaf_inventory_path(sap_sid => $sap_sid, config_root_path => $config_root_path);
    my $private_key_src_path = get_sut_sshkey_path(config_root_path => $config_root_path);

    # Connect serial to Deployer VM to get inventory file
    connect_target_to_serial();
    sdaf_ssh_key_from_keyvault(key_vault => $workload_key_vault, target_file => $private_key_src_path);

    my $inventory_data = read_inventory_file($inventory_path);
    # From now on all commands will be executed on worker VM
    disconnect_target_from_serial();

    # Download ssh private key for accessing SUTs
    my $scp_cmd = join(' ', 'scp ', "$jump_host_user\@$jump_host_ip:$private_key_src_path", $sut_private_key_path);
    assert_script_run($scp_cmd);

    # Share inventory data between all tests
    $run_args->{sdaf_inventory} = $inventory_data;
    # Create console redirection data
    $run_args->{redirection_data} = create_redirection_data(inventory_data => $inventory_data);

    prepare_ssh_config(
        inventory_data => $inventory_data,
        jump_host_ip => $jump_host_ip,
        jump_host_user => $jump_host_user
    );
    # checks SSH connection to each host executing simple command
    verify_ssh_proxy_connection(inventory_data => $inventory_data);
}

1;
