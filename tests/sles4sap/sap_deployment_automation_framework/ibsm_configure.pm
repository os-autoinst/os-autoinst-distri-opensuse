# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Setup peering between SUT VNET and IBSM VNET

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::azure_cli;
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection;

=head1 NAME

sles4sap/sap_deployment_automation_framework/ibsm_configure.pm - Setup connection between ISBM and Workload zone VNETs.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Test module sets up network peering between tests workload zone and IBSM VNET.

B<The key tasks performed by this module include:>

=over

=item * Verifies if test module was executed with 'IS_MAINTENANCE' OpenQA setting and returns if IBSM connection is not required.

=item * Collects data required for creating network peerings

=item * Creates resources for two way peering between two VNETs

=item * Creates DNS zone and record for all SUTs to access ISBM host using FQDN defined by OpenQA setting B<'REPO_MIRROR_HOST'>

=item * Verifies if peering resources were created

=back

=head1 OPENQA SETTINGS

=over

=item * B<IBSM_RG> : IBSM resource group name

=item * B<IS_MAINTENANCE> : Define if test scenario includes applying maintenance updates

=item * B<REPO_MIRROR_HOST> : IBSM repository hostname

=back
=cut

sub test_flags {
    return {fatal => 1};
}

sub run {
    unless (get_var('IS_MAINTENANCE')) {
        # Just a safeguard for case the module is in schedule without 'IS_MAINTENANCE' OpenQA setting being set
        record_info('MAINTENANCE OFF', 'OpenQA setting "IS_MAINTENANCE" is disabled, skipping IBSm setup');
        return;
    }

    select_serial_terminal();
    my $ibsm_rg = get_required_var('IBSM_RG');
    my $ibsm_vnet_name = ${az_network_vnet_get(resource_group => $ibsm_rg)}[0];

    my $nic_count = az_network_nic_list(resource_group => $ibsm_rg, query => 'length([].ipConfigurations)');
    die "There must be exactly 1 IBSM NIC. Found : '$nic_count'" unless ($nic_count == 1);

    my $deploy_id = find_deployment_id();
    my $workload_resource_group =
      ${az_group_name_get(query => "[?contains(name, 'workload') && contains(name, '$deploy_id')].name")}[0];
    my $workload_vnet_name = ${az_network_vnet_get(resource_group => $workload_resource_group)}[0];
    my $ibsm_peering_name = get_ibsm_peering_name(source_vnet => $ibsm_vnet_name, target_vnet => $workload_vnet_name);
    my $workload_peering_name = get_ibsm_peering_name(source_vnet => $workload_vnet_name, target_vnet => $ibsm_vnet_name);

    # Create two way network peering
    az_network_peering_create(
        name => $ibsm_peering_name,
        source_rg => $ibsm_rg,
        source_vnet => $ibsm_vnet_name,
        target_rg => $workload_resource_group,
        target_vnet => $workload_vnet_name
    );
    az_network_peering_create(
        name => $workload_peering_name,
        source_rg => $workload_resource_group,
        source_vnet => $workload_vnet_name,
        target_rg => $ibsm_rg,
        target_vnet => $ibsm_vnet_name
    );

    # Create DNS zone for maintenance repository mirror
    my ($subdomain, $second_level, $tld) = split('\.', get_required_var('REPO_MIRROR_HOST'));
    my $zone_name = "$second_level.$tld";
    my $ibsm_ip = ${az_network_nic_list(resource_group => $ibsm_rg,
            query => '"[].ipConfigurations[0].privateIPAddress"')}[0];

    record_info(
        'IBSM DNS', "Private DNS zone: $zone_name\nDNS record: $ibsm_ip -> " . get_required_var('REPO_MIRROR_HOST'));
    az_network_dns_zone_create(resource_group => $workload_resource_group, name => $zone_name);
    az_network_dns_add_record(
        resource_group => $workload_resource_group, zone_name => $zone_name, record_name => $subdomain, ip_addr => $ibsm_ip);
    az_network_dns_link_create(
        resource_group => $workload_resource_group,
        zone_name => $zone_name,
        vnet => $workload_vnet_name,
        name => $workload_vnet_name
    );

    # Report and verify result
    record_info('Peering check', 'Verifying if peering resources were created');
    for my $peering_arguments (
        {resource_group => $workload_resource_group, vnet => $workload_vnet_name, name => $workload_peering_name},
        {resource_group => $ibsm_rg, vnet => $ibsm_vnet_name, name => $ibsm_peering_name})
    {
        die("Peering '$peering_arguments->{name}' not detected after creation")
          unless az_network_peering_exists(%$peering_arguments);
        record_info('PEERING OK', "Peering '$peering_arguments->{name}' created successfully.");
    }
}

1;
