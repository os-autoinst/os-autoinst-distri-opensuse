# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Deploy a VM in the cloud (Azure, AWS, GCP) for crash testing.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/crash/deploy.pm - Cloud Infrastructure Deployment for Crash Testing

=head1 DESCRIPTION

C<deploy.pm> creates and configures the necessary Public Cloud infrastructure (AWS, Azure, or GCP) to support crash testing.

Its primary tasks are:

=over

=item * Initialize the cloud provider factory and validate configuration.

=item * Calculate unique network address ranges based on C<WORKER_ID> to avoid collisions.

=item * Deploy provider-specific infrastructure (VPC/VNet, subnets, security groups, VM).

=item * Verify initial VM connectivity (especially for AWS).

=back

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

The cloud provider to use: 'EC2', 'AZURE', or 'GCE'. Required.

=item B<PUBLIC_CLOUD_REGION>

Cloud region where resources will be created. Required.

=item B<PUBLIC_CLOUD_INSTANCE_TYPE>

VM instance type to launch. Required. Defaults to 'n1-standard-2' for GCE if not specified.

=item B<WORKER_ID>

OpenQA worker ID used to calculate unique network address ranges. Required.

=item B<PUBLIC_CLOUD_EC2_ACCOUNT_ID>

AWS account ID.

=item B<PUBLIC_CLOUD_IMAGE_LOCATION>

Optional image location for Azure.

=item B<PUBLIC_CLOUD_AVAILABILITY_ZONE>

Availability zone for the cloud provider. Required for GCE.

=item B<PUBLIC_CLOUD_GOOGLE_PROJECT_ID>

GCP project ID. Required for GCE.

=item B<PUBLIC_CLOUD_IMAGE_PROJECT>

GCP image project. Required for GCE.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

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
            region => $provider->provider_client->region,
            ssh_pub_key => $provider->ssh_key . ".pub",
            image_name => $provider->get_image_id(),
            image_owner => get_var('PUBLIC_CLOUD_EC2_ACCOUNT_ID', '679593333241'),
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
            region => $provider->provider_client->region,
            ssh_pub_key => $provider->ssh_key . ".pub",
            os => $os_ver,
            address_range => $range{main_address_range},
            subnet_range => $range{subnet_address_range});
    }
    elsif ($provider_type eq 'GCE') {
        crash_deploy_gcp(
            region => $provider->provider_client->region,
            ssh_pub_key => $provider->ssh_key . '.pub',
            availability_zone => get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE'),
            project => get_required_var('PUBLIC_CLOUD_GOOGLE_PROJECT_ID'),
            image_name => $provider->get_image_id() =~ s/.*\///r,
            image_project => get_required_var('PUBLIC_CLOUD_IMAGE_PROJECT'),
            machine_type => get_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'n1-standard-2'),
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
