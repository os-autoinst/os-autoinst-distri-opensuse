# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: This module is responsible for creating all necessary Azure resources:
# - Azure Resource Group
# - Network Security Group and SSH rule
# - Virtual Network and Subnet
# - Public IP and NIC
# - VM creation from image or VHD blob
# It saves VM public IP and SSH command into job variables

use base 'publiccloud::basetest';
use testapi;
use publiccloud::utils;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use sles4sap::azure_cli;
use utils;
use version_utils;


sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for this test')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $azure_prefix = get_var('DEPLOY_PREFIX', 'clne');
    my $rg = $azure_prefix . get_current_job_id();

    select_serial_terminal;

    my $provider = $self->provider_factory();

    my $os_ver;
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        $os_ver = $self->{provider}->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os_ver = $provider->get_image_id();
    }

    assert_script_run('rm ~/.ssh/config');

    az_group_create(name => $rg, region => $provider->provider_client->region);

    if ($os_ver =~ /\.vhd$/) {
        my $img_name = $rg . 'img';
        az_img_from_vhd_create(
            resource_group => $rg,
            name => $img_name,
            source => $os_ver);
        $os_ver = $img_name;
    }

    my $nsg = $azure_prefix . '-nsg';
    az_network_nsg_create(resource_group => $rg, name => $nsg);
    az_network_nsg_rule_create(resource_group => $rg, nsg => $nsg, name => $nsg . 'RuleSSH', port => 22);

    my $pub_ip_prefix = $azure_prefix . '-pub_ip';
    az_network_publicip_create(resource_group => $rg, name => $pub_ip_prefix, zone => '1 2 3');

    my $vnet = $azure_prefix . '-vnet';
    my $subnet = $azure_prefix . '-snet';
    az_network_vnet_create(
        resource_group => $rg,
        region => $provider->provider_client->region,
        vnet => $vnet,
        address_prefixes => '10.1.0.0/16',
        snet => $subnet,
        subnet_prefixes => '10.1.0.0/24');

    my $nic = $azure_prefix . '-nic';
    assert_script_run(join(' ', 'az network nic create',
            '--resource-group', $rg,
            '--name', $nic,
            '--vnet-name', $vnet,
            '--subnet', $subnet,
            '--network-security-group', $nsg,
            '--private-ip-address-version IPv4',
            '--public-ip-address', $pub_ip_prefix));

    my $vm = $azure_prefix . '-vm';
    my %vm_create_args = (
        resource_group => $rg,
        name => $vm,
        image => $os_ver,
        nic => $nic,
        username => 'cloudadmin',
        region => $provider->provider_client->region);
    $vm_create_args{security_type} = 'Standard' if is_sle('<=12-SP5');

    az_vm_create(%vm_create_args);

    my $vm_ip = az_network_publicip_get(resource_group => $rg, name => $azure_prefix . "-pub_ip");
    my $ssh_cmd = 'ssh cloudadmin@' . $vm_ip;

    set_var('VM_IP', $vm_ip);
    set_var('SSH_CMD', $ssh_cmd);
    set_var('RG', $rg);
    set_var('VM_NAME', $vm);
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    az_group_delete(name => get_var('DEPLOY_PREFIX', 'clne') . get_current_job_id(), timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
