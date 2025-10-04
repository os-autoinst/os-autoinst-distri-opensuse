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
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection;
use sles4sap::sap_deployment_automation_framework::basetest qw(sdaf_ibsm_teardown);

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
    my $sap_sid = get_required_var('SAP_SID');
    my $sdaf_config_root_dir = get_sdaf_config_path(
        deployment_type => 'sap_system',
        vnet_code => get_workload_vnet_code(),
        env_code => get_required_var('SDAF_ENV_CODE'),
        sdaf_region_code => convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION')),
        sap_sid => $sap_sid);

    my $ibsm_rg = get_required_var('IBSM_RG');
    my $ibsm_vnet_name = ${az_network_vnet_get(resource_group => $ibsm_rg)}[0];

    my $nic_count = az_network_nic_list(resource_group => $ibsm_rg, query => 'length([].ipConfigurations)');
    die "There must be exactly 1 IBSM NIC. Found : '$nic_count'" unless ($nic_count == 1);

    # Gather information

    my $deploy_id = find_deployment_id();
    my $workload_resource_group =
      ${az_group_name_get(query => "[?contains(name, 'workload') && contains(name, '$deploy_id')].name")}[0];
    my $workload_vnet_name = ${az_network_vnet_get(resource_group => $workload_resource_group)}[0];

    # Create two way network peering
    my $peering_ibsm = az_network_peering_create(
        name => get_ibsm_peering_name(source_vnet => $ibsm_vnet_name, target_vnet => $workload_vnet_name),
        source_rg => $ibsm_rg,
        source_vnet => $ibsm_vnet_name,
        target_rg => $workload_resource_group,
        target_vnet => $workload_vnet_name
    );
    my $peering_workload = az_network_peering_create(
        name => get_ibsm_peering_name(source_vnet => $workload_vnet_name, target_vnet => $ibsm_vnet_name),
        source_rg => $workload_resource_group,
        source_vnet => $workload_vnet_name,
        target_rg => $ibsm_rg,
        target_vnet => $ibsm_vnet_name
    );
    record_info('IBSM Peering', "Peering result:\n" . Dumper($peering_ibsm) . "\n" . Dumper($peering_workload));

    # Connect serial to Deployer VM to get SSH key to SUT
    connect_target_to_serial();
    load_os_env_variables();
    az_login();
    sdaf_execute_playbook(
        playbook_filename => 'pb_get-sshkey.yaml', timeout => 90, sdaf_config_root_dir => $sdaf_config_root_dir);
    disconnect_target_from_serial();
    sdaf_ibsm_teardown();

}

1;
