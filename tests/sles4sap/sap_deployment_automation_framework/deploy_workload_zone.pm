# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deployment of the workload zone using SDAF automation

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::sap_deployment_automation_framework::configure_tfvars qw(prepare_tfvars_file);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(no_cleanup_tag);
use sles4sap::sap_deployment_automation_framework::networking qw(assign_address_space calculate_subnets);
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    # Skip module if existing deployment is being re-used
    return if sdaf_deployment_reused();

    serial_console_diag_banner('Module sdaf_deploy_workload_zone.pm : start');
    select_serial_terminal();

    # From now on everything is executed on Deployer VM (residing on cloud).
    connect_target_to_serial();
    load_os_env_variables();

    # Setup Workload zone openQA variables - used for tfvars template
    set_var('SDAF_RESOURCE_GROUP', generate_resource_group_name(deployment_type => 'workload_zone'));

    my $workload_vnet_code = get_workload_vnet_code();
    set_var('SDAF_VNET_CODE', $workload_vnet_code);
    # 'vnet_code' variable changes with deployment type.
    set_os_variable('vnet_code', $workload_vnet_code);

    # Test code searches for unused address space by listing existing network peerings. There is however time period
    # between test assigning free network internally and actually creating network peering. During that time, network
    # won't appear in any checks using az-cli command.
    # This time is calculated by multiplying max terraform runtime with number of retries done. Result is increased by
    # additional 30m buffer.
    # Tests will therefore attempt to assign only networks which are older than max terraform runtime.
    my $terraform_retries = 3;
    my $terraform_timeout = 1800;
    my $networks_older_than = $terraform_retries * $terraform_timeout + 1800;

    # reserve network address space either by reusing already existing one or create a new file
    record_info('Network search', 'Searching for unused network space.');
    my $network_space = assign_address_space(networks_older_than => $networks_older_than);
    die 'Test failed to acquire a free network address space' unless $network_space;

    my %network_data = %{calculate_subnets(network_space => $network_space)};

    my $network_info_message = join("\n", map { "$_: $network_data{$_}" } keys(%network_data));
    record_info('Networking', $network_info_message);
    for my $variable_name (keys(%network_data)) {
        set_var(uc($variable_name), $network_data{$variable_name});
    }

    # Add no cleanup tag if the deployment should be kept after test finished
    set_var('SDAF_NO_CLEANUP', '"' . no_cleanup_tag() . '" = "1"') if get_var('SDAF_RETAIN_DEPLOYMENT');

    prepare_tfvars_file(deployment_type => 'workload_zone');
    az_login();
    sdaf_execute_deployment(
        deployment_type => 'workload_zone',
        retries => $terraform_retries,
        timeout => $terraform_timeout);

    # disconnect the console
    disconnect_target_from_serial();

    # reset temporary variables
    set_var('SDAF_RESOURCE_GROUP', undef);
    set_var('SDAF_VNET_CODE', undef);
    serial_console_diag_banner('Module sdaf_deploy_workload_zone.pm : end');
}

1;
