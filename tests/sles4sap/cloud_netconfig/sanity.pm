# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Check that deployed resource in the cloud are as expected
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::JSON qw(decode_json);
use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;

    die 'Azure is the only CSP supported for the moment' unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $rg = 'clne' . get_current_job_id();
    my $az_cmd;

    # Check that the resource group exist
    assert_script_run("az group list --query \"[].name\" -o tsv | grep $rg");

    # Check that the VM is running (from the point of view of the CSP)
    assert_script_run("az vm list --resource-group $rg -d --query \"[?powerState=='VM running'].name\" -o tsv | grep clne-vm");

    # get the username
    my $vm_user = script_output("az vm list --resource-group $rg --query '[0].osProfile.adminUsername' -o tsv");
    record_info('TEST STEP', 'Cloud resources are up and running');

    my $vm_ip;
    my $ssh_cmd;
    my $ret;
    # check that the VM is reachable using both public IP addresses
    foreach (1 .. 2) {
        $vm_ip = script_output("az network public-ip show --resource-group $rg --name clne-pub_ip-$_ --query 'ipAddress' -o tsv");
        $ssh_cmd = 'ssh ' . $vm_user . '@' . $vm_ip;

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

    # print (no check for the moment) the OS release description
    assert_script_run("$ssh_cmd cat /etc/os-release");
    record_info('TEST STEP', 'is-system-running OK');

    # Check that cloud-netconfig is installed
    assert_script_run("$ssh_cmd sudo zypper ref");    # Needed in the PAYG images
    assert_script_run("$ssh_cmd zypper se -s -i cloud-netconfig");
    assert_script_run("$ssh_cmd cat /etc/default/cloud-netconfig");
    assert_script_run("$ssh_cmd sudo journalctl |grep -E 'cloud-netconfig\\['");
    record_info('TEST STEP', 'cloud-netconfig OK');

    # print the NIC configuration
    assert_script_run("$ssh_cmd ip a show eth0");
    assert_script_run("$ssh_cmd ip -br -c addr show eth0");
    assert_script_run("$ssh_cmd hostname -i");
    assert_script_run("$ssh_cmd cat /etc/host.conf | grep multi");

    # check to have exactly 3 IPv4 IpConfigs
    assert_script_run("$ssh_cmd ip a show eth0 | grep -c 'inet ' | grep 3");
    record_info('TEST STEP', 'Network interface OK');

    # CSP has internal API to query how the resources are configured on the cloud side.
    # cloud-netconfig query this API from within the running VM to adjust
    # the OS configuration to what is configured on the cloud side.
    # check if the CSP API is reachable from within the VM (cloud-netconfig will use it too)
    my $curl_cmd = join(' ', $ssh_cmd,
        "curl -s -H Metadata:true --noproxy '*':",
        'http://169.254.169.254/metadata/instance/network/interface/\?api-version\=2021-02-01');
    assert_script_run("$curl_cmd | python3 -m json.tool");

    # now check the content of data returned by the CSP API is like
    # what has been configured for this deployment
    my $res = decode_json(script_output("$curl_cmd | python3 -m json.tool"));
    # Count the elements in the "ipAddress" list
    my $num_ip_configs = 0;
    foreach my $ip_address (@{$res->[0]->{ipv4}->{ipAddress}}) {
        $num_ip_configs++;
    }
    die "The number of IpConfigs is $num_ip_configs and not 3" unless 3 == $num_ip_configs;
    record_info('TEST STEP', 'Cloud API OK');
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
