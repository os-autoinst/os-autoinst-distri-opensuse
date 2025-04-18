# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Registration SUT
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use publiccloud::utils;
use sles4sap::qesap::qesapdeployment qw (qesap_az_vnet_peering_delete);
use sles4sap::ipaddr2 qw(
  ipaddr2_deployment_logs
  ipaddr2_cloudinit_logs
  ipaddr2_infra_destroy
  ipaddr2_scc_addons
  ipaddr2_refresh_repo
  ipaddr2_ssh_internal
  ipaddr2_bastion_pubip
  ipaddr2_azure_resource_group
);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $bastion_pubip = ipaddr2_bastion_pubip();

    # Addons registration not needed at the moment
    #ipaddr2_scc_addons(bastion_pubip => $bastion_pubip);
    foreach my $id (1 .. 2) {
        # refresh repo
        ipaddr2_refresh_repo(id => $id, bastion_pubip => $bastion_pubip);

        # record repo lr
        ipaddr2_ssh_internal(id => $id,
            cmd => "sudo zypper lr",
            bastion_ip => $bastion_pubip);
        # record repo ls
        ipaddr2_ssh_internal(id => $id,
            cmd => "sudo zypper ls",
            bastion_ip => $bastion_pubip);
    }
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
