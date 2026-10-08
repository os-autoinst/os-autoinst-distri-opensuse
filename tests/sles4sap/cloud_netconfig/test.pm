# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Tests cloud-netconfig
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

cloud_netconfig/test.pm - Test cloud-netconfig network interface removal

=head1 DESCRIPTION

This module tests the C<cloud-netconfig> service's ability to dynamically
update the guest OS's network configuration in response to changes made on the
cloud provider. In particular check that cloud-netconfig correctly removes
a network interface after its deletion on the cloud provider.

The test performs the following actions:

=over 4

=item * Deletes a secondary IP configuration ('ipconfig2') from the VM's network interface using the Azure CLI.

=item * Polls the Azure metadata endpoint from within the VM to confirm the cloud-side change is visible.

=item * Polls the VM's network interface (C<eth0>) to verify that the IP address associated with the deleted configuration (C<10.1.0.5>) has been removed by C<cloud-netconfig>.

=back

This ensures that C<cloud-netconfig> is correctly monitoring for and applying network configuration changes from the cloud environment.

=head1 VARIABLES

=over 4

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. Currently, only 'AZURE' is supported for this test.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use Mojo::JSON qw(decode_json);
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use sles4sap::azure_cli;

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
    my $vm_ip = az_network_publicip_get(resource_group => $rg, name => DEPLOY_PREFIX . "-pub_ip-1");
    my $ssh_cmd = 'ssh ' . $vm_user . '@' . $vm_ip;

    # Delete an ip-config
    az_ipconfig_delete(
        resource_group => $rg,
        ipconfig_name => DEPLOY_PREFIX . '-nic',
        nic_name => 'ipconfig2');

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
    az_group_delete(name => DEPLOY_PREFIX . get_current_job_id(), timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
