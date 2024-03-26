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

use constant DEPLOY_PREFIX => 'clne';

sub run {
    my ($self) = @_;

    die 'Azure is the only CSP supported for the moment' unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $rg = DEPLOY_PREFIX . get_current_job_id();
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
    my $vnet = DEPLOY_PREFIX . '-vnet';
    my $subnet = DEPLOY_PREFIX . '-snet';
    $az_cmd = join(' ', 'az network vnet create',
        '--resource-group', $rg,
        '--location', $provider->provider_client->region,
        '--name', $vnet,
        '--address-prefixes 10.1.0.0/16',
        '--subnet-name', $subnet,
        '--subnet-prefixes 10.1.0.0/24');
    assert_script_run($az_cmd);

    # Create two Public IP
    my $pub_ip_prefix = DEPLOY_PREFIX . '-pub_ip-';
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
    my $nsg = DEPLOY_PREFIX . '-nsg';
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
    $az_cmd = join(' ', 'az vm create',
        '--resource-group', $rg,
        '--name', $vm,
        '--nics', $nic,
        '--image', $os_ver,
        '--admin-username cloudadmin',
        '--authentication-type ssh',
        '--generate-ssh-keys');
    assert_script_run($az_cmd, timeout => 600);

    my $vm_ip;
    my $ssh_cmd;
    my $ret;
    # check that the VM is reachable using both public IP addresses
    foreach (1 .. 2) {
        $az_cmd = join(' ',
            'az network public-ip show',
            "--resource-group $rg",
            '--name', DEPLOY_PREFIX . "-pub_ip-$_",
            '--query "ipAddress"',
            '-o tsv');
        $vm_ip = script_output($az_cmd);
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
                '-e "testing@suse.com"'));
        assert_script_run(join(' ', $ssh_cmd, 'sudo', 'SUSEConnect -s'));
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
