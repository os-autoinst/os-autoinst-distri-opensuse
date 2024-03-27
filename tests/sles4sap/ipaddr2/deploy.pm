# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create a VM with a single NIC and 3 ip-config
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use sles4sap::azure_cli;

use constant DEPLOY_PREFIX => 'ip2t';

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $rg = DEPLOY_PREFIX . get_current_job_id();
    my $os_ver = get_required_var('CLUSTER_OS_VER');

    select_serial_terminal;

    # Init all the PC gears (ssh keys, CSP credentials)
    my $provider = $self->provider_factory();

    az_group_create($rg, $provider->provider_client->region);

    # Create a VNET only needed later when creating the VM
    my $vnet = DEPLOY_PREFIX . '-vnet';
    my $subnet = DEPLOY_PREFIX . '-snet';
    my $priv_ip_range = '192.168.0';
    az_network_vnet_create(
        resource_group => $rg,
        region => $provider->provider_client->region,
        vnet => $vnet,
        address_prefixes => '192.168.0.0/16',
        snet => $subnet,
        subnet_prefixes => $priv_ip_range . '.0/16');

    # Create a Network Security Group only needed later when creating the VM
    my $nsg = DEPLOY_PREFIX . '-nsg';
    az_network_nsg_create(
        resource_group => $rg,
        name => $nsg);

    # Create the only one public IP of this deployment,
    # it will be assigned to the 3rd VM (bastion role)
    my $bastion_pub_ip = DEPLOY_PREFIX . '-pub_ip';
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
        frontend_ip => $lb_fe,
        fip => $lb_feip,
        sku => 'Standard');


    # All the 2 VM will be later assigned to it.
    # The load balancer does not explicitly knows about it
    my $as = DEPLOY_PREFIX . '-as';
    az_vm_as_create(
        resource_group => $rg,
        name => $as,
        region => $provider->provider_client->region,
        fault_count => 2);

    # Create 2:
    #   - VMs
    #   - for each of them open port 80
    #   - link their NIC/ipconfigs to the load balancer to be managed
    my $cloud_init_file = '/tmp/cloud-init-web.txt';
    assert_script_run(join(' ',
            'curl -v -fL',
            data_url('sles4sap/cloud-init-web.txt'),
            '-o', $cloud_init_file));
    for (my $i = 0; $i < get_var('IPADDR2_VMS', 2); $i++) {
        my $vm = DEPLOY_PREFIX . "-vm-0$i";
        # the VM creation command refers to an external cloud-init
        # configuration file that is in charge to install and setup
        # the nginx server.
        az_vm_create(
            resource_group => $rg,
            name => $vm,
            region => $provider->provider_client->region,
            image => $os_ver,
            username => 'cloudadmin',
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
            username => 'cloudadmin');

        az_vm_openport(resource_group => $rg, name => $vm, port => 80);
    }

    $vm = DEPLOY_PREFIX . "-vm-bastion";
    az_vm_create(
        resource_group => $rg,
        name => $vm,
        region => $provider->provider_client->region,
        image => $os_ver,
        username => 'cloudadmin',
        vnet => $vnet,
        snet => $subnet,
        ssh_pubkey => get_ssh_private_key_path() . '.pub',
        public_ip => $bastion_pub_ip);


    # Keep this loop separated from the other to hopefully
    # give cloud-init more time to run
    for (my $i = 0; $i < get_var('IPADDR2_VMS', 2); $i++) {
        my $vm = DEPLOY_PREFIX . "-vm-0$i";
        my $nic_id = az_nic_id_get(
            resource_group => $rg,
            name => $vm);
        my $ip_config = az_ipconfig_name_get(nic_id => $nic_id);
        my $nic_name = az_nic_name_get(nic_id => $nic_id);
        #echo "The just created VM ${THIS_VM} has THIS_IP_CONFIG:${THIS_IP_CONFIG} and THIS_NIC:${THIS_NIC}"

     # Change the IpConfig to use a static IP: https://documentation.suse.com/sle-ha/15-SP5/html/SLE-HA-all/article-installation.html#vl-ha-inst-quick-req-other
        #az network nic ip-config update \
        #  --name $THIS_IP_CONFIG \
        #  --resource-group $MY_GROUP \
        #  --nic-name $THIS_NIC \
        #  --private-ip-address "${MY_PRIV_IP_RANGE}.4${NUM}"

        # Add the IpConfig to the LB pool
        #echo "--> az network nic ip-config address-pool add"
        #az network nic ip-config address-pool add \
        #  -g $MY_GROUP \
        #  --lb-name $MY_LB \
        #  --address-pool $MY_BE_POOL \
        #  --ip-config-name $THIS_IP_CONFIG \
        #  --nic-name $THIS_NIC
    }

}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $rg = DEPLOY_PREFIX . get_current_job_id();
    script_run("az group delete --name $rg -y", timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
