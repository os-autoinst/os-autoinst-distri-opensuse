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
  ipaddr2_get_internal_vm_name
  ipaddr2_deployment_sanity
);

use constant DEPLOY_PREFIX => 'ip2t';

our $user = 'cloudadmin';
our $bastion_vm_name = DEPLOY_PREFIX . "-vm-bastion";
our $bastion_pub_ip = DEPLOY_PREFIX . '-pub_ip';
our $priv_ip_range = '192.168.';
our $frontend_ip = $priv_ip_range . '0.50';

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
    az_network_vnet_create(
        resource_group => $rg,
        region => $args{region},
        vnet => $vnet,
        address_prefixes => $priv_ip_range . '0.0/16',
        snet => $subnet,
        subnet_prefixes => $priv_ip_range . '0.0/24');

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
    az_network_lb_create(
        resource_group => $rg,
        name => $lb,
        vnet => $vnet,
        snet => $subnet,
        backend => $lb_be,
        frontend_ip_name => $lb_fe,
        fip => $frontend_ip,
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
        $vm = ipaddr2_get_internal_vm_name(id => $i);
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

    az_vm_create(
        resource_group => $rg,
        name => $bastion_vm_name,
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
        my $vm = ipaddr2_get_internal_vm_name(id => $i);
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

=head2 ipaddr2_deployment_sanity

    ipaddr2_deployment_sanity()

Run some checks on the existing deployment using the
az command line.
die in case of failure
=cut

sub ipaddr2_deployment_sanity {
    my $rg = ipaddr2_azure_resource_group();
    my $res = az_group_name_get();
    my $count = grep(/$rg/, @$res);
    die "There are not exactly one but $count resource groups with name $rg" unless $count eq 1;

    $res = az_vm_name_get(resource_group => $rg);
    $count = grep(/$bastion_vm_name/, @$res);
    die "There are not exactly 3 VMs but " . ($#{$res} + 1) unless ($#{$res} + 1) eq 3;
    die "There are not exactly 1 but $count VMs with name $bastion_vm_name" unless $count eq 1;

    foreach my $i (1 .. 2) {
        my $vm = ipaddr2_get_internal_vm_name(id => $i);
        $res = az_vm_instance_view_get(
            resource_group => $rg,
            name => $vm);
        # Expected return is
        # [ "PowerState/running", "VM running" ]
        $count = grep(/running/, @$res);
        die "VM $vm is not fully running" unless $count eq 2;    # 2 is two occurrence of the word 'running' for one VM
    }
}

=head2 ipaddr2_destroy

    ipaddr2_destroy();

Destroy the deployment by deleting the resource group
=cut

sub ipaddr2_destroy {
    my $rg = ipaddr2_azure_resource_group();
    assert_script_run("az group delete --name $rg -y", timeout => 600);
}

=head2 ipaddr2_get_internal_vm_name

    my $vm_name = ipaddr2_get_internal_vm_name(42);

compose and return a string for the vm name
=cut

sub ipaddr2_get_internal_vm_name {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};
    return DEPLOY_PREFIX . "-vm-0$args{id}";
}

1;
