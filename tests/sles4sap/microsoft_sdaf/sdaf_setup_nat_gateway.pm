# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deployment of the SAP systems zone using SDAF automation

# Required OpenQA variables:
#     'SDAF_WORKLOAD_VNET_CODE' Virtual network code for workload zone.

use parent 'sles4sap::microsoft_sdaf_basetest';

use strict;
use warnings;
use testapi;
use sles4sap::console_redirection;
use sles4sap::sdaf_library;
use sles4sap::azure_cli;
use serial_terminal qw(select_serial_terminal);

sub test_flags {
    return {fatal => 1};
}

sub run {
    serial_console_diag_banner('Module sdaf_setup_nat_gateway.pm : start');
    select_serial_terminal();

    # Define variables
    my $env_code = get_required_var('SDAF_ENV_CODE');
    my $sdaf_region_code = convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));
    my $vnet_code = get_required_var('SDAF_WORKLOAD_VNET_CODE');
    my $resource_group = generate_resource_group_name(deployment_type => 'workload_zone');
    my $vnet_name = @{az_network_vnet_list(resource_group => $resource_group)}[0];
    my $subnet_list = az_network_vnet_subnet_list(resource_group => $resource_group, vnet_name => $vnet_name);
    my $public_ip_res_name = sdaf_public_ip_name_gen(
        env_code => $env_code,
        sdaf_region_code => $sdaf_region_code,
        vnet_code => $vnet_code
    );
    my $gateway_res_name = sdaf_nat_gateway_name_gen(
        env_code => $env_code,
        sdaf_region_code => $sdaf_region_code,
        vnet_code => $vnet_code
    );

    # Create public IP
    az_network_publicip_create(resource_group => $resource_group, name => $public_ip_res_name, timeout => 180);

    # Create gateway
    az_network_nat_gateway_create(
        resource_group => $resource_group,
        gateway_name => $gateway_res_name,
        public_ip => $public_ip_res_name
    );

    # Associate gateway with each subnet
    for my $subnet_name (@$subnet_list) {
        az_network_vnet_subnet_update(
            resource_group => $resource_group,
            gateway_name => $gateway_res_name,
            subnet_name => $subnet_name,
            vnet_name => $vnet_name
        );
    }

    serial_console_diag_banner('Module sdaf_setup_nat_gateway.pm : end');
}

1;
