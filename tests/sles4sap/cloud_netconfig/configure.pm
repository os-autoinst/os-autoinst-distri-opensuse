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

sub run {
    my ($self) = @_;

    die 'Azure is the only CSP supported for the moment' unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $rg = 'clne' . get_current_job_id();
    my $os_ver = get_required_var('CLUSTER_OS_VER');

    select_serial_terminal;

    # Init all the PC gears (ssh keys, CSP credentials)
    my $provider = $self->provider_factory();

    my $az_cmd;

    # Create a resource group to contain all
    $az_cmd = join(' ', 'az group create',
        '--name', $rg,
        '--location', $provider->provider_client->region);
    assert_script_run($az_cmd);

    # Create a virtual network with a subnet
    my $vnet = 'clne-vnet';
    my $subnet = 'clne-snet';
    $az_cmd = join(' ', 'az network vnet create',
        '--resource-group', $rg,
        '--location', $provider->provider_client->region,
        '--name', $vnet,
        '--address-prefixes 10.1.0.0/16',
        '--subnet-name', $subnet,
        '--subnet-prefixes 10.1.0.0/24');
    assert_script_run($az_cmd);

    # Create two Public IP
    my $pub_ip_prefix = 'clne-pub_ip-';
    foreach (1 .. 2) {
        $az_cmd = join(' ', 'az network public-ip create',
            '--resource-group', $rg,
            '--name', $pub_ip_prefix . $_,
            '--sku Standard',
            '--version IPv4',
            '--zone 1 2 3');
        assert_script_run($az_cmd);
    }

    # Create security rule to allow ssh
    my $nsg = 'clne-nsg';
    $az_cmd = join(' ', 'az network nsg create',
        '--resource-group', $rg,
        '--name', $nsg);
    assert_script_run($az_cmd);

    $az_cmd = join(' ', 'az network nsg rule create',
        '--resource-group', $rg,
        '--nsg-name', $nsg,
        '--name', $nsg . 'RuleSSH',
        "--protocol '*'",
        '--direction inbound',
        "--source-address-prefix '*'",
        "--source-port-range '*'",
        "--destination-address-prefix '*'",
        '--destination-port-range 22',
        '--access allow',
        '--priority 200');
    assert_script_run($az_cmd);

    # Create one NIC, by default it also create a ip configuration
    # Associate the first public IP to this default first IpConfig
    # No private IP associated to this first IpConfig: DHCP
    my $nic = 'clne-nic';
    $az_cmd = join(' ', 'az network nic create',
        '--resource-group', $rg,
        '--name', $nic,
        '--vnet-name', $vnet,
        '--subnet', $subnet,
        '--network-security-group', $nsg,
        '--private-ip-address-version IPv4',
        '--public-ip-address', $pub_ip_prefix . '1');
    assert_script_run($az_cmd);

    # Create a second additional IpConfig associated to the same NIC
    # Associate the second public IP to this second IpConfig
    # Static private IP
    $az_cmd = join(' ', 'az network nic ip-config create',
        '--resource-group', $rg,
        '--name ipconfig2',
        '--nic-name', $nic,
        '--vnet-name', $vnet,
        '--subnet', $subnet,
        '--private-ip-address 10.1.0.5',
        '--private-ip-address-version IPv4',
        '--public-ip-address', $pub_ip_prefix . '2');
    assert_script_run($az_cmd);

    # Create a third IpConfig associated to the same NIC
    # No public IP to this third IpConfig
    # Static private IP
    $az_cmd = join(' ', 'az network nic ip-config create',
        '--resource-group', $rg,
        '--name ipconfig3',
        '--nic-name', $nic,
        '--vnet-name', $vnet,
        '--subnet', $subnet,
        '--private-ip-address 10.1.0.6',
        '--private-ip-address-version IPv4');
    assert_script_run($az_cmd);

    # Create one VM and add the NIC to it
    my $vm = 'clne-vm';
    $az_cmd = join(' ', 'az vm create',
        '--resource-group', $rg,
        '--name', $vm,
        '--nics', $nic,
        '--image', $os_ver,
        '--admin-username cloudadmin',
        '--authentication-type ssh',
        '--generate-ssh-keys');
    assert_script_run($az_cmd, timeout => 600);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $rg = 'clne' . get_current_job_id();
    script_run("az group delete --name $rg -y", timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
