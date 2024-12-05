# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executes setup of HanaSR scenario using SDAF ansible playbooks according to:
#           https://learn.microsoft.com/en-us/azure/sap/automation/tutorial#sap-application-installation

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use sles4sap::azure_cli qw(az_keyvault_list);
use sles4sap::sap_deployment_automation_framework::inventory_tools;
use sles4sap::sap_deployment_automation_framework::deployment qw(sdaf_ssh_key_from_keyvault);
use sles4sap::sap_deployment_automation_framework::naming_conventions
  qw( get_sdaf_inventory_path
  convert_region_to_short
  get_workload_vnet_code
  $sut_private_key_path
  generate_resource_group_name);

sub run {
    my ($self, $run_args) = @_;
    select_serial_terminal;

    # Connect serial to Deployer VM to get inventory file
    connect_target_to_serial();

    my $jump_host_user = get_required_var('REDIRECT_DESTINATION_USER');
    my $jump_host_ip = get_required_var('REDIRECT_DESTINATION_IP');

    my $inventory_path = get_sdaf_inventory_path(
        env_code => get_required_var('SDAF_ENV_CODE'),
        sdaf_region_code => convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION')),
        vnet_code => get_workload_vnet_code(),
        sap_sid => get_required_var('SAP_SID')
    );
    my $inventory_data = read_inventory_file($inventory_path);
    # From now on all commands will be executed on worker VM
    disconnect_target_from_serial();

    # Share inventory data between all tests
    $run_args->{sdaf_inventory} = $inventory_data;
    # Create console redirection data
    $run_args->{redirection_data} = create_redirection_data(inventory_data => $inventory_data);

    my @workload_key_vault = @{az_keyvault_list(
            resource_group => generate_resource_group_name(deployment_type => 'workload_zone'))};
    die "There needs to be exactly 1 workload key vault present. Value returned:\n" . join("\n", @workload_key_vault)
      unless @workload_key_vault == 1;

    sdaf_ssh_key_from_keyvault(key_vault => $workload_key_vault[0], target_file => $sut_private_key_path);

    prepare_ssh_config(
        inventory_data => $inventory_data,
        jump_host_ip => $jump_host_ip,
        jump_host_user => $jump_host_user
    );
    # checks SSH connection to each host executing simple command
    verify_ssh_proxy_connection(inventory_data => $inventory_data);
}

1;
