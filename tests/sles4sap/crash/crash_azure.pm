# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executes a crash scenario on azure.

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use sles4sap::azure_cli;
use utils 'script_retry';

use constant DEPLOY_PREFIX => 'clne';

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for this test')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $rg = DEPLOY_PREFIX . get_current_job_id();

    select_serial_terminal;

    my $provider = $self->provider_factory();

    my $os_ver;
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        # This section is only needed by Azure tests using images uploaded
        # with publiccloud_upload_img.
        $os_ver = $self->{provider}->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os_ver = get_required_var('CLUSTER_OS_VER');
    }

    # remove configuration file created by the PC factory
    # as it interfere with ssh behavior.
    assert_script_run('rm ~/.ssh/config');

    az_group_create(name => $rg, region => $provider->provider_client->region);

    # If image provided is a blob storage link, create image out of it
    if ($os_ver =~ /\.vhd$/) {
        my $img_name = $rg . 'img';
        az_img_from_vhd_create(
            resource_group => $rg,
            name => $img_name,
            source => $os_ver);
        $os_ver = $img_name;
    }

    my $pub_ip_prefix = DEPLOY_PREFIX . '-pub_ip-';
    az_network_publicip_create(
        resource_group => $rg,
        name => $pub_ip_prefix . $_,
        zone => '1 2 3');
     my $nic = DEPLOY_PREFIX . '-nic';
    $az_cmd = join(' ', 'az network nic create',
        '--resource-group', $rg,
        '--name', $nic,
        '--private-ip-address-version IPv4',
        '--public-ip-address', $pub_ip_prefix . '1');
    assert_script_run($az_cmd);
    # Create one VM
    my $vm = DEPLOY_PREFIX . '-vm';
    my %vm_create_args = (
        resource_group => $rg,
        name => $vm,
        image => $os_ver,
        nic => $nic,
        username => 'cloudadmin',
        region => $provider->provider_client->region);
    $vm_create_args{security_type} = 'Standard' if is_sle '<=12-SP5';

    az_vm_create(%vm_create_args);

    my $vm_ip;
    my $ssh_cmd;
    my $ret;
    # check that the VM is reachable using public IP addresses
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
    record_info('TEST STEP', 'VM reachable with SSH');

    my %system_register_args = (
        reg_code => get_var('SCC_REGCODE_SLES4SAP'),
        ssh_command => $ssh_cmd);
    ensure_system_ready_and_register(%system_register_args);

    # Crash test
    my $patch_output = script_output(join(' ',
            $ssh_cmd,
            'sudo', 'zypper',
            '--non-interactive', 'patch'), proceed_on_failure => 1);
    if ($patch_output =~ /Run this command once more to install any other needed patches/) {
        record_info("Zypper Warning", "Detected request to rerun zypper patch");
        assert_script_run(join(' ',
                $ssh_cmd,
                'sudo',
                'zypper', '--non-interactive',
                'patch'),
            timeout => 600);
    }
    assert_script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'reboot'),
        timeout => 600);
    select_serial_terminal;
    wait_serial(qr/\#/, timeout => 600);

    assert_script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'su -c',
            "\"echo 'b' > /proc/sysrq-trigger &\""),
        timeout => 600);
    script_retry("nc -zv $vm_ip 22", retry => 10, delay => 45);
    assert_script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'systemctl',
            "--failed"),
        timeout => 600);
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
