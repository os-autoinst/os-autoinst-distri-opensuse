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
use version_utils 'is_sle';
use sles4sap::azure_cli;

use constant DEPLOY_PREFIX => 'clne';

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $rg = DEPLOY_PREFIX . get_current_job_id();
    my $os_ver = get_required_var('CLUSTER_OS_VER');

    select_serial_terminal;

    # Init all the PC gears (ssh keys, CSP credentials)
    my $provider = $self->provider_factory();
    # remove configuration file created by the PC factory
    # as it interfere with ssh behavior.
    # in particular it has setting about verbosity that
    # break test steps that relay to remote ssh comman output
    assert_script_run('rm ~/.ssh/config');

    az_group_create(name => $rg, region => $provider->provider_client->region);

    # Create a virtual network with a subnet
    my $vnet = DEPLOY_PREFIX . '-vnet';
    my $subnet = DEPLOY_PREFIX . '-snet';
    az_network_vnet_create(
        resource_group => $rg,
        region => $provider->provider_client->region,
        vnet => $vnet,
        address_prefixes => '10.1.0.0/16',
        snet => $subnet,
        subnet_prefixes => '10.1.0.0/24');

    # Create two Public IP
    my $az_cmd;
    my $pub_ip_prefix = DEPLOY_PREFIX . '-pub_ip-';
    foreach (1 .. 2) {
        az_network_publicip_create(
            resource_group => $rg,
            name => $pub_ip_prefix . $_,
            zone => '1 2 3');
    }

    # Create security rule to allow ssh
    my $nsg = DEPLOY_PREFIX . '-nsg';
    az_network_nsg_create(
        resource_group => $rg,
        name => $nsg);

    az_network_nsg_rule_create(
        resource_group => $rg,
        nsg => $nsg,
        name => $nsg . 'RuleSSH',
        port => 22);

    # Create one NIC, by default it also create a ip configuration
    # Associate the first public IP to this default first IpConfig
    # No private IP associated to this first IpConfig: DHCP
    my $nic = DEPLOY_PREFIX . '-nic';
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
    my $vm = DEPLOY_PREFIX . '-vm';
    my %vm_create_args = (
        resource_group => $rg,
        name => $vm,
        nic => $nic,
        image => $os_ver,
        username => 'cloudadmin',
        region => $provider->provider_client->region);
    $vm_create_args{security_type} = 'Standard' if is_sle '<=12-SP5';

    az_vm_create(%vm_create_args);

    my $vm_ip;
    my $ssh_cmd;
    my $ret;
    # check that the VM is reachable using both public IP addresses
    foreach (1 .. 2) {
        $vm_ip = az_network_publicip_get(resource_group => $rg, name => DEPLOY_PREFIX . "-pub_ip-$_");
        $ssh_cmd = 'ssh cloudadmin@' . $vm_ip;

        my $start_time = time();
        # Looping until SSH port 22 is reachable or timeout.
        while ((time() - $start_time) < 300) {
            $ret = script_run("nc -vz -w 1 $vm_ip 22", quiet => 1);
            last if defined($ret) and $ret == 0;
            sleep 10;
        }
        assert_script_run("ssh-keyscan $vm_ip | tee -a ~/.ssh/known_hosts");
    }
    record_info('TEST STEP', 'VM reachable with SSH');

    # Looping until is-system-running or timeout.
    my $start_time = time();
    while ((time() - $start_time) < 300) {
        $ret = script_run("$ssh_cmd sudo systemctl is-system-running");
        last unless $ret;
        sleep 10;
    }

    if (my $reg_code = get_var('SCC_REGCODE_SLES4SAP')) {
        assert_script_run(join(' ',
                $ssh_cmd,
                'sudo', 'registercloudguest',
                '--force-new',
                '-r', "\"$reg_code\"",
                '-e "testing@suse.com"'),
            timeout => 600);
        assert_script_run(join(' ', $ssh_cmd, 'sudo', 'SUSEConnect -s'));
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    az_group_delete(name => DEPLOY_PREFIX . get_current_job_id(), timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
