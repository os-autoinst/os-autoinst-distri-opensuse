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
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
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
    prepare_tfvars_file(deployment_type => 'workload_zone');
    az_login();
    sdaf_execute_deployment(deployment_type => 'workload_zone');

    # diconnect the console
    disconnect_target_from_serial();

    # reset temporary variables
    set_var('SDAF_RESOURCE_GROUP', undef);
    set_var('SDAF_VNET_CODE', undef);
    serial_console_diag_banner('Module sdaf_deploy_workload_zone.pm : end');
}

1;
