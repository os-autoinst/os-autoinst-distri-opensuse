# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Check that deployed resource in the cloud are as expected
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::ipaddr2;

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
    # and change the routing from the frontend IP to the
    # backend IP of the VM-02
    ipaddr2_crm_move(bastion_ip => $bastion_ip, destination => 2);
    sleep 30;

    # use curl to probe the webserver using the frontend IP
    # until the reply come from the VM-02
    die "Takeover does not happens in time" unless ipaddr2_wait_for_takeover(bastion_ip => $bastion_ip, destination => 2);
    #test_connectivity
    ipaddr2_test_master_vm(bastion_ip => $bastion_ip, id => 2);
    #test_other_vm "${MYNAME}-vm-01"

    #ssh_node1 'sudo crm configure show' | grep -E "cli-prefer-.*${MYNAME}-vm-02" || test_die "Cluster should now have one cli-prefer- with ${MYNAME}-vm-02"
    #ssh_node1 'sudo crm configure show' | grep -c cli-prefer- | grep 1 || test_die "Cluster should now have one cli-prefer-"

    # Slow down, take a break, then check again, nothing should be changed.
    #test_step "Check again later"
    #sleep 30
    #test_connectivity
    #test_web "${MYNAME}-vm-02"

#################################################################################
    # Repeat the same but this time from VM-02 to VM-01
    #test_step "Move back the IpAddr2 resource to VM1"
    #ssh_node1 'sudo crm resource move '"${MY_MOVE_RES} ${MYNAME}-vm-01" || test_die "Error in resource move"
    #sleep 30

    #wait_for_takeover "${MYNAME}-vm-01"
    #test_connectivity
    #test_on_vm "${MYNAME}-vm-01"
    #test_other_vm "${MYNAME}-vm-02"

    #test_step "Clear all location constrain used during the test"
    #ssh_node1 'sudo crm resource clear '"${MY_MOVE_RES}"
    #sleep 30

    #test_step "Check cluster after the clear"
    #ssh_node1 'sudo crm configure show' | grep -c cli-prefer- | grep 0 || test_die "Cluster should no more have some cli-prefer-"
    #ssh_node1 'sudo crm status'

    # Slow down, take a break, then check again, nothing should be changed.
    #test_step "Check again later"
    #sleep 30
    #test_connectivity
    #test_web "${MYNAME}-vm-01"


}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_os_cloud_init_logs() if (check_var('IPADDR2_CLOUDINIT', 1));
    ipaddr2_destroy();
    $self->SUPER::post_fail_hook;
}

1;
