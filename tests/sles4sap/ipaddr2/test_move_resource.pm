# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Check that deployed resource in the cloud are as expected
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::qesap::qesapdeployment qw (qesap_az_vnet_peering_delete);
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_pubip
  ipaddr2_crm_clear
  ipaddr2_crm_move
  ipaddr2_deployment_logs
  ipaddr2_infra_destroy
  ipaddr2_cloudinit_logs
  ipaddr2_os_connectivity_sanity
  ipaddr2_test_master_vm
  ipaddr2_test_other_vm
  ipaddr2_wait_for_takeover
  ipaddr2_azure_resource_group
);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $bastion_ip = ipaddr2_bastion_pubip();

    # 1. get the webpage using the LB floating IP. It should be from VM1 at the test beginning
    # 2. move the cluster resource on the VM2
    # 3. get the webpage using the LB floating IP. It should be from VM2

    # This step is using crm to explicitly move rsc_ip_00 to VM-02
    # as the IP resource is grouped with the az loadbalancer one,
    # the load balancer entity in Azure is notified about the move
    # and should change the routing from the frontend IP to the
    # backend IP of the VM-02
    ipaddr2_crm_move(bastion_ip => $bastion_ip, destination => 2);
    sleep 30;

    # probe the webserver using the frontend IP
    # until the reply come from the VM-02
    die "Takeover does not happens in time" unless ipaddr2_wait_for_takeover(bastion_ip => $bastion_ip, destination => 2);

    ipaddr2_os_connectivity_sanity();

    # Check the status on the VM that is supposed to be
    # the master for the webservice
    ipaddr2_test_master_vm(bastion_ip => $bastion_ip, id => 2);
    ipaddr2_test_other_vm(bastion_ip => $bastion_ip, id => 1);

    # Slow down, take a break, then check again, nothing should be changed.
    sleep 60;
    ipaddr2_os_connectivity_sanity();
    ipaddr2_test_master_vm(bastion_ip => $bastion_ip, id => 2);
    ipaddr2_test_other_vm(bastion_ip => $bastion_ip, id => 1);

    # Repeat the same but this time from VM-02 to VM-01
    #test_step "Move back the IpAddr2 resource to VM1"
    ipaddr2_crm_move(bastion_ip => $bastion_ip, destination => 1);
    sleep 30;

    die "Takeover does not happens in time" unless ipaddr2_wait_for_takeover(bastion_ip => $bastion_ip, destination => 1);

    ipaddr2_os_connectivity_sanity();
    ipaddr2_test_master_vm(bastion_ip => $bastion_ip, id => 1);
    ipaddr2_test_other_vm(bastion_ip => $bastion_ip, id => 2);

    # Slow down, take a break, then check again, nothing should be changed.
    sleep 60;
    ipaddr2_os_connectivity_sanity();
    ipaddr2_test_master_vm(bastion_ip => $bastion_ip, id => 1);
    ipaddr2_test_other_vm(bastion_ip => $bastion_ip, id => 2);

    # Clear all location constrain used during the test
    ipaddr2_crm_clear(bastion_ip => $bastion_ip);
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
