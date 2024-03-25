# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: remove one of the 3 IpConfigs using az and check that
#          clodu-netconfig is able to apply changes in the OS
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::JSON qw(decode_json);
use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';

use constant DEPLOY_PREFIX => 'clne';

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $rg = DEPLOY_PREFIX . get_current_job_id();
    my $az_cmd;

    $az_cmd = join(' ',
        'az vm list',
        "--resource-group $rg",
        '--query "[0].osProfile.adminUsername"',
        '-o tsv');
    my $vm_user = script_output($az_cmd);

    $az_cmd = join(' ',
        'az network public-ip show',
        "--resource-group $rg",
        '--name', DEPLOY_PREFIX . '-pub_ip-1',
        '--query "ipAddress"',
        '-o tsv');
    my $vm_ip = script_output($az_cmd);
    my $ssh_cmd = 'ssh ' . $vm_user . '@' . $vm_ip;

    # Delete an ip-config
    $az_cmd = join(' ', 'az network nic ip-config delete',
        '--resource-group', $rg,
        '--name ipconfig2',
        '--nic-name', DEPLOY_PREFIX . '-nic');
    assert_script_run($az_cmd);

    # Intermediate optional test, check on the cloud side
    my $curl_cmd = join(' ', $ssh_cmd,
        "curl -s -H Metadata:true --noproxy '*':",
        'http://169.254.169.254/metadata/instance/network/interface/\?api-version\=2021-02-01');
    my $start_time = time();
    while ((time() - $start_time) < 300) {
        my $res = decode_json(script_output("$curl_cmd | python3 -m json.tool"));
        # Count the elements in the "ipAddress" list
        my $num_ip_configs = 0;
        foreach my $ip_address (@{$res->[0]->{ipv4}->{ipAddress}}) {
            $num_ip_configs++;
        }
        last if 2 == $num_ip_configs;
        sleep 10;
    }

    # Check that cloud-netconfig removed the IpConfig
    # as result of the change on the cloud side.
    $start_time = time();
    while ((time() - $start_time) < 300) {
        last unless script_output("$ssh_cmd ip a show eth0 | grep '10.1.0.5'", proceed_on_failure => 1);
        sleep 10;
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
