# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create network peering with IBSm
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::qesap::qesapdeployment qw (qesap_az_vnet_peering_delete);
use sles4sap::ipaddr2 qw(
  ipaddr2_deployment_logs
  ipaddr2_cloudinit_logs
  ipaddr2_infra_destroy
  ipaddr2_network_peering_create
  ipaddr2_add_server_repos_to_hosts
  ipaddr2_azure_resource_group
);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Create network peering
    ipaddr2_network_peering_create(ibsm_rg => get_required_var('IBSM_RG'));

    ipaddr2_add_server_repos_to_hosts(ibsm_ip => get_required_var('IBSM_IP'), incident_repo => get_var('INCIDENT_REPO', ''));
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_cloudinit_logs() unless check_var('IPADDR2_CLOUDINIT', 0);
    if (my $ibsm_rg = get_var('IBSM_RG')) {
        qesap_az_vnet_peering_delete(source_group => ipaddr2_azure_resource_group(), target_group => $ibsm_rg);
    }
    ipaddr2_infra_destroy();
    $self->SUPER::post_fail_hook;
}

1;
