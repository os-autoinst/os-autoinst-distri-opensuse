# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Setup peering between SUT VNET and IBSM VNET

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

package ibsm_configure;

use testapi;
use serial_terminal qw(select_serial_terminal);
use Data::Dumper;
use sles4sap::azure_cli
  qw(az_network_vnet_get az_network_nic_list az_group_name_get az_network_peering_create az_network_vnet_show);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);
use sles4sap::sap_deployment_automation_framework::naming_conventions;

=head1 NAME

sles4sap/redirection_tests/check_ensa2_cluster.pm - Perform checks and display status screens for ENSA2 cluster.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Modu executes checks and provides status screens for ENSA2 cluster. It is intended to be used on a healthy
cluster, for example after a deployment is finished or at the end of a test sequence. In case of unhealthy cluster,
test will fail.

B<The key tasks performed by this module include:>

=over

=item * Collects connection data to all ENSA2 cluster nodes required for console redirection

=back

=head1 OPENQA SETTINGS

=over

=item * B<IBSM_RG> : IBSM resource group name

=back
=cut


sub run {
    select_serial_terminal();
    my $ibsm_rg = get_required_var('IBSM_RG');
    my $ibsm_vnet_name = ${az_network_vnet_get(resource_group => $ibsm_rg)}[0];

    my $nic_count = az_network_nic_list(resource_group => $ibsm_rg, query => 'length([].ipConfigurations)');
    die "There must be exactly 1 IBSM NIC. Found : '$nic_count'" unless ($nic_count == 1);

    # Gather information
    my $ibsm_ip = ${az_network_nic_list(resource_group => $ibsm_rg,
            query => '"[].ipConfigurations[0].privateIPAddress"')}[0];
    my $deploy_id = find_deployment_id();
    my $workload_resource_group =
      ${az_group_name_get(query => "[?contains(name, 'workload') && contains(name, '$deploy_id')].name")}[0];
    my $workload_vnet_name = ${az_network_vnet_get(resource_group => $workload_resource_group)}[0];

    # Create twoi way network peering
    my $peering_a = az_network_peering_create(
        name => get_ibsm_peering_name(source_vnet => $ibsm_vnet_name, target_vnet => $workload_vnet_name),
        source_rg => $ibsm_rg,
        source_vnet => $ibsm_vnet_name,
        target_rg => $workload_resource_group,
        target_vnet => $workload_vnet_name
    );
    my $peering_b = az_network_peering_create(
        name => get_ibsm_peering_name(source_vnet => $workload_vnet_name, target_vnet => $ibsm_vnet_name),
        source_rg => $workload_resource_group,
        source_vnet => $workload_vnet_name,
        target_rg => $ibsm_rg,
        target_vnet => $ibsm_vnet_name
    );
    record_info('IBSM Peering', "Peering result:\n" . Dumper($peering_a) . "\n" . Dumper($peering_b));
    # Verify connection

}

1;
