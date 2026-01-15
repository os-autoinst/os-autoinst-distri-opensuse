# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Setup peering between SUT VNET and IBSm VNET

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::azure_cli;
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);
use sles4sap::sap_deployment_automation_framework::basetest qw(sdaf_ibsm_data_collect);
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection;
use sles4sap::ibsm qw(ibsm_network_peering_azure_create);

=head1 NAME

sles4sap/sap_deployment_automation_framework/ibsm_configure.pm - Setup connection between ISBM and Workload zone VNETs.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Test module sets up network peering between tests workload zone and IBSm VNET.

B<The key tasks performed by this module include:>

=over

=item * Verifies if test module was executed with 'IS_MAINTENANCE' OpenQA setting and returns if IBSm connection is not required.

=item * Collects data required for creating network peerings

=item * Creates resources for two way peering between two VNETs

=item * Creates DNS zone and record for all SUTs to access ISBM host using FQDN defined by OpenQA setting B<'REPO_MIRROR_HOST'>

=item * Verifies if peering resources were created

=back

=head1 OPENQA SETTINGS

=over

=item * B<IBSM_RG> : IBSm resource group name

=item * B<IS_MAINTENANCE> : Define if test scenario includes applying maintenance updates

=item * B<REPO_MIRROR_HOST> : IBSm repository hostname

=back
=cut

sub test_flags {
    return {fatal => 1};
}

sub run {
    # Skip module if existing deployment is being re-used
    return if sdaf_deployment_reused();

    unless (get_var('IS_MAINTENANCE')) {
        # Just a safeguard for case the module is in schedule without 'IS_MAINTENANCE' OpenQA setting being set
        record_info('MAINTENANCE OFF', 'OpenQA setting "IS_MAINTENANCE" is disabled, skipping IBSm setup');
        return;
    }

    select_serial_terminal();
    my $ibsm_rg = get_required_var('IBSM_RG');
    my $nic_count = az_nic_list(resource_group => $ibsm_rg, query => 'length([].ipConfigurations)');

    die <<"die_message"
Current code implementation expects IBSM resource group to have only one NIC.
Found : '$nic_count'
Investigate what is the reason and adapt code changes if required.
die_message
      unless ($nic_count == 1);

    my $peering_data = sdaf_ibsm_data_collect();

    for my $peering_type (keys %{$peering_data}) {
        my $data = $peering_data->{$peering_type};
        # There should not be an existing peering with the same name - might be leftover.
        die "Network peering '$data->{peering_name}' already exists" if $data->{exists};
    }

    # Create two way network peering
    ibsm_network_peering_azure_create(
        ibsm_rg => $peering_data->{ibsm_peering}{source_resource_group},
        sut_rg => $peering_data->{workload_peering}{source_resource_group},
        name_prefix => 'SDAF');

    # Check the two way network peering
    for my $peering_type (keys %{$peering_data}) {
        my $data = $peering_data->{$peering_type};

        die("Peering '$data->{peering_name}' not detected after creation")
          unless az_network_peering_exists(
            resource_group => $data->{source_resource_group},
            vnet => $data->{source_vnet},
            name => $data->{peering_name});
        record_info('Peering OK', <<"record_info"
Peering '$data->{peering_name}' created:
Resource_group: $data->{source_resource_group}
Source VNET: $data->{source_vnet}
Target VNET: $data->{target_vnet}
record_info
        );
    }

    # Create DNS zone for maintenance repository mirror
    my ($subdomain, $second_level, $tld) = split('\.', get_required_var('REPO_MIRROR_HOST'));
    my $zone_name = "$second_level.$tld";
    my $ibsm_ip = ${az_nic_list(resource_group => $ibsm_rg,
            query => '"[].ipConfigurations[0].privateIPAddress"')}[0];
    my $workload_resource_group = $peering_data->{workload_peering}{source_resource_group};
    my $workload_vnet_name = $peering_data->{workload_peering}{source_vnet};

    record_info(
        'IBSm DNS', "Private DNS zone: $zone_name\nDNS record: $ibsm_ip -> " . get_required_var('REPO_MIRROR_HOST'));
    az_network_dns_zone_create(resource_group => $workload_resource_group, name => $zone_name);
    az_network_dns_add_record(
        resource_group => $workload_resource_group, zone_name => $zone_name, record_name => $subdomain, ip_addr => $ibsm_ip);
    az_network_dns_link_create(
        resource_group => $workload_resource_group,
        zone_name => $zone_name,
        vnet => $workload_vnet_name,
        name => $workload_vnet_name
    );
}
1;
