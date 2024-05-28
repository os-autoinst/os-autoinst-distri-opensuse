# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library sub and shared data for the ipaddr2 cloud test.

package sles4sap::ipaddr2;
use strict;
use warnings FATAL => 'all';
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use mmapi 'get_current_job_id';
use sles4sap::azure_cli;
use publiccloud::utils;


=head1 SYNOPSIS

Library to manage ipaddr2 tests
=cut

our @EXPORT = qw(
  $user
  ipaddr2_azure_deployment
  ipaddr2_ssh_cmd
  ipaddr2_destroy
);

use constant DEPLOY_PREFIX => 'ip2t';

our $user = 'cloudadmin';
our $bastion_pub_ip = DEPLOY_PREFIX . '-pub_ip';

=head2 ipaddr2_azure_resource_group

    my $rg = ipaddr2_azure_resource_group();

Get the Azure resource group name for this test
=cut

sub ipaddr2_azure_resource_group {
    return DEPLOY_PREFIX . get_current_job_id();
}

=head2 ipaddr2_azure_deployment

    my $rg = ipaddr2_azure_deployment();

Create a deployment in Azure designed for this specific test.

1. Create a resource group to contain all
2. Create a vnet and subnet in it
3. Create one Public IP
4. Create 2 VM to run the cluster, both running a webserver and that are behind the LB
5. Create 1 additional VM that get
6. Create a Load Balancer with 2 VM in backend and with an IP as frontend

=over 2

=item B<region> - existing resource group

=item B<os> - existing Load balancer NAME

=back
=cut

sub ipaddr2_azure_deployment {
    my (%args) = @_;
    foreach (qw(region os)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    az_version();

    my $rg = ipaddr2_azure_resource_group();

    az_group_create(
        name => $rg,
        region => $args{region});

    # Create a VNET only needed later when creating the VM
    my $vnet = DEPLOY_PREFIX . '-vnet';
    my $subnet = DEPLOY_PREFIX . '-snet';
    my $priv_ip_range = '192.168.0';
    az_network_vnet_create(
        resource_group => $rg,
        region => $args{region},
        vnet => $vnet,
        address_prefixes => $priv_ip_range . '.0/16',
        snet => $subnet,
        subnet_prefixes => $priv_ip_range . '.0/24');

    # Create a Network Security Group
    # only needed later when creating the VM
    my $nsg = DEPLOY_PREFIX . '-nsg';
    az_network_nsg_create(
        resource_group => $rg,
        name => $nsg);

    # Create the only one public IP in this deployment,
    # it will be assigned to the 3rd VM (bastion role)
    az_network_publicip_create(
        resource_group => $rg,
        name => $bastion_pub_ip,
        sku => 'Basic',
        allocation_method => 'Static');

    # Create the load balancer entity.
    # Mostly this one is just a "group" definition
    # to link back-end (2 VMs) and front-end (the Pub IP) resources
    # SKU Standard (and not Basic) is needed to get some Metrics
    my $lb = DEPLOY_PREFIX . '-lb';
    my $lb_be = DEPLOY_PREFIX . '-backend_pool';
    my $lb_fe = DEPLOY_PREFIX . '-frontent_ip';
    my $lb_feip = $priv_ip_range . '.50';
    az_network_lb_create(
        resource_group => $rg,
        name => $lb,
        vnet => $vnet,
        snet => $subnet,
        backend => $lb_be,
        frontend_ip_name => $lb_fe,
        fip => $lb_feip,
        sku => 'Standard');

    # All the 2 VM will be later assigned to it.
    # The load balancer does not explicitly knows about it
    my $as = DEPLOY_PREFIX . '-as';
    az_vm_as_create(
        resource_group => $rg,
        name => $as,
        region => $args{region},
        fault_count => 2);

    # Create 2:
    #   - VMs
    #   - for each of them open port 80
    #   - link their NIC/ipconfigs to the load balancer to be managed
    my $vm;
    my $cloud_init_file = '/tmp/cloud-init-web.txt';
    assert_script_run(join(' ',
            'curl -v -fL',
            data_url('sles4sap/cloud-init-web.txt'),
            '-o', $cloud_init_file));
    foreach my $i (1 .. 2) {
        $vm = DEPLOY_PREFIX . "-vm-0$i";
        # the VM creation command refers to an external cloud-init
        # configuration file that is in charge to install and setup
        # the nginx server.
        az_vm_create(
            resource_group => $rg,
            name => $vm,
            region => $args{region},
            image => $args{os},
            username => $user,
            vnet => $vnet,
            snet => $subnet,
            availability_set => $as,
            nsg => $nsg,
            custom_data => $cloud_init_file,
            ssh_pubkey => get_ssh_private_key_path() . '.pub',
            public_ip => "");

        az_vm_wait_cloudinit(
            resource_group => $rg,
            name => $vm,
            username => $user);

        az_vm_openport(
            resource_group => $rg,
            name => $vm, port => 80);
    }

    $vm = DEPLOY_PREFIX . "-vm-bastion";
    az_vm_create(
        resource_group => $rg,
        name => $vm,
        region => $args{region},
        image => $args{os},
        username => $user,
        vnet => $vnet,
        snet => $subnet,
        ssh_pubkey => get_ssh_private_key_path() . '.pub',
        public_ip => $bastion_pub_ip);

    # Keep this loop separated from the other to hopefully
    # give cloud-init more time to run and avoid interfering
    # with it by changing the networking on the running VM
    foreach my $i (1 .. 2) {
        my $vm = DEPLOY_PREFIX . "-vm-0$i";
        my $nic_id = az_nic_id_get(
            resource_group => $rg,
            name => $vm);
        my $ip_config = az_ipconfig_name_get(nic_id => $nic_id);
        my $nic_name = az_nic_name_get(nic_id => $nic_id);

        # Change the IpConfig to use a static IP:
        # https://documentation.suse.com/sle-ha/15-SP5/html/SLE-HA-all/article-installation.html#vl-ha-inst-quick-req-other
        az_ipconfig_update(
            resource_group => $rg,
            ipconfig_name => $ip_config,
            nic_name => $nic_name,
            ip => $priv_ip_range . '4' . $i);

        # Add the IpConfig to the LB pool
        az_ipconfig_pool_add(
            resource_group => $rg,
            lb_name => $lb,
            address_pool => $lb_be,
            ipconfig_name => $ip_config,
            nic_name => $nic_name);
    }

    # Health probe is using the port exposed by the cluster RA azure-lb
    # to understand if each of the VM in the cluster is OK
    # Is probably eventually the cluster itself that
    # cares to monitor the below service (port 80)
    my $lbhp = $lb . "_health";
    my $lbhp_port = '62500';
    az_network_lb_probe_create(
        resource_group => $rg,
        lb_name => $lb,
        name => $lbhp,
        port => $lbhp_port);

    # Configure the load balancer behavior
    az_network_lb_rule_create(
        resource_group => $rg,
        lb_name => $lb,
        hp_name => $lbhp,
        backend => $lb_be,
        frontend_ip => $lb_fe,
        name => $lb . "_rule",
        port => '80');
}

=head2 ipaddr2_ssh_cmd

    script_run(ipaddr2_ssh_cmd() . ' whoami');

Create ssh command that target the only VM
in the deployment that has public IP.
=cut

sub ipaddr2_ssh_cmd {
    my $rg = ipaddr2_azure_resource_group();
    my $pub_ip_addr = az_network_publicip_get(
        resource_group => $rg,
        name => $bastion_pub_ip);

    return 'ssh ' . $user . '@' . $pub_ip_addr;
}

=head2 ipaddr2_destroy

    ipaddr2_destroy();

Destroy the deployment by deleting the resource group
=cut

sub ipaddr2_destroy {
    my $rg = ipaddr2_azure_resource_group();
    assert_script_run("az group delete --name $rg -y", timeout => 600);
}

1;
