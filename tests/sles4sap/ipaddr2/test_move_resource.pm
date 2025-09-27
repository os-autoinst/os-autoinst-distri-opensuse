# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test the movement of an IPaddr2 cluster resource between two VMs.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/test_move_resource - Test IPaddr2 resource migration in a cluster

=head1 DESCRIPTION

This test verifies the functionality of moving an IPaddr2 cluster resource
between two virtual machines in a high-availability setup. It uses `crm`
commands to move the resource and then checks if the web service is correctly
served from the new master node. The test performs the move in both directions
(VM1 to VM2 and VM2 to VM1) and includes sanity checks for OS connectivity and
cluster status.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IPADDR2_DIAGNOSTIC>

If set to 1, deployment logs are collected in case of a test failure.

=item B<IPADDR2_CLOUDINIT>

If not set to 0, cloud-init logs are collected in case of a test failure.

=item B<IBSM_RG>

The name of the resource group for the IBSM (Infrastructure Backup and Support
Module), used for cleaning up network peerings.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_pubip
  ipaddr2_crm_clear
  ipaddr2_crm_move
  ipaddr2_os_connectivity_sanity
  ipaddr2_test_master_vm
  ipaddr2_test_other_vm
  ipaddr2_wait_for_takeover
  ipaddr2_cleanup
  ipaddr2_logs_collect);

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
    ipaddr2_logs_collect();
    ipaddr2_cleanup(
        diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0),
        cloudinit => get_var('IPADDR2_CLOUDINIT', 1),
        ibsm_rg => get_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
