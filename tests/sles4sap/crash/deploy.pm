# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deploy a VM in the cloud (Azure, AWS, GCP) for crash testing.

=head1 SYNOPSIS

Creates and configures Public Cloud infrastructure for crash testing.
This test module supports AWS (EC2), Azure (AZURE), and GCP (GCE).
It sets up the necessary networking, security groups, and launches a VM instance.

B<Required OpenQA variables:>

=over

=item * B<PUBLIC_CLOUD_PROVIDER> - 'EC2', 'AZURE' or 'GCE'

=item * B<PUBLIC_CLOUD_REGION> - Cloud region where resources will be created

=item * B<PUBLIC_CLOUD_INSTANCE_TYPE> - VM instance type to launch

=back

B<Test flow:>

1. Validates the cloud provider and initializes the provider factory.

2. Cleans up any existing SSH configuration.

3. Calls the appropriate deployment function from C<sles4sap::crash> based on the provider.

4. For AWS, it performs an additional connectivity check.

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils;
use serial_terminal 'select_serial_terminal';
use utils qw(script_retry);
use sles4sap::aws_cli;
use sles4sap::crash;
use sles4sap::ibsm;

sub run {
    my ($self) = @_;
    my $provider_type = get_required_var('PUBLIC_CLOUD_PROVIDER');

    select_serial_terminal;
    my $provider = $self->provider_factory();
    assert_script_run('rm -f ~/.ssh/config');

    my %range = ibsm_calculate_address_range(slot => get_required_var('WORKER_ID'));

    if ($provider_type eq 'EC2') {
        my $instance_id = crash_deploy_aws(
            region => get_var('PUBLIC_CLOUD_REGION'),
            image_name => $provider->get_image_id(),
            image_owner => get_var('PUBLIC_CLOUD_EC2_ACCOUNT_ID', '679593333241'),
            ssh_pub_key => $provider->ssh_key . ".pub",
            instance_type => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
            address_range => $range{main_address_range},
            subnet_range => $range{subnet_address_range});

        my $ip_address = aws_get_ip_address(instance_id => $instance_id);
        my $ssh_cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user\@$ip_address";
        script_retry("$ssh_cmd hostnamectl", 90, delay => 15, retry => 12);
    }
    elsif ($provider_type eq 'AZURE') {
        my $os_ver = get_var('PUBLIC_CLOUD_IMAGE_LOCATION') ?
          $self->{provider}->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) :
          $provider->get_image_id();
        crash_deploy_azure(
            os => $os_ver,
            region => $provider->provider_client->region,
            address_range => $range{main_address_range},
            subnet_range => $range{subnet_address_range});
    }
    elsif ($provider_type eq 'GCE') {
        crash_deploy_gcp(
            region => get_required_var('PUBLIC_CLOUD_REGION'),
            availability_zone => get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE'),
            project => get_required_var('PUBLIC_CLOUD_GOOGLE_PROJECT_ID'),
            image_name => $provider->get_image_id() =~ s/.*\///r,
            image_project => get_required_var('PUBLIC_CLOUD_IMAGE_PROJECT'),
            machine_type => get_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'n1-standard-2'),
            ssh_pub_key => $provider->ssh_key . '.pub',
            subnet_range => $range{subnet_address_range});
    }
    else {
        die("Unsupported provider: $provider_type");
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $provider = get_var('PUBLIC_CLOUD_PROVIDER');
    if ($provider) {
        my %clean_args = (provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'));
        $clean_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
        crash_cleanup(%clean_args);
    }
    $self->SUPER::post_fail_hook;
}

1;
