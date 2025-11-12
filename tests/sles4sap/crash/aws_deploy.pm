# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deploy a vm in aws.


=head1 SYNOPSIS

Creates and configures AWS EC2 infrastructure using AWS CLI.
This test module sets up a complete VPC environment including networking components,
security groups, and launches an EC2 instance with SSH access.

The test performs the following operations:
=over

=item * Creates a VPC with specified CIDR block

=item * Sets up security groups for instance access control

=item * Creates and configures subnet within the VPC

=item * Establishes internet gateway and routing for external connectivity

=item * Configures SSH access rules in security group

=item * Launches an EC2 instance with the specified AMI and instance type

=item * Waits for instance to reach running state and establishes SSH connection

=back

B<Required OpenQA variables:>

=over

=item * B<PUBLIC_CLOUD_PROVIDER> - Must be set to 'EC2'. This is the only supported CSP for this test.

=item * B<PUBLIC_CLOUD_REGION> - AWS region where resources will be created (e.g., 'us-east-1', 'eu-west-1')

=item * B<PUBLIC_CLOUD_IMAGE_ID> - AMI ID to use for the EC2 instance

=item * B<PUBLIC_CLOUD_NEW_INSTANCE_TYPE> - EC2 instance type to launch (e.g., 't2.micro', 'm5.large')

=back

B<Optional OpenQA variables:>

=over

=item * B<DEPLOY_PREFIX> - Prefix for resource naming and tagging. Default: 'clne'

=item * B<PUBLIC_CLOUD_IMAGE_LOCATION> - Alternative image location. If set, overrides PUBLIC_CLOUD_IMAGE_ID

=back

B<Test flow:>

1. Validates that PUBLIC_CLOUD_PROVIDER is set to 'EC2'

2. Imports SSH key pair for instance authentication

3. Creates VPC with /28 CIDR block (10.0.0.0/28)

4. Sets up security group with descriptive tags

5. Creates subnet within the VPC

6. Establishes internet gateway and attaches it to VPC

7. Configures route table for internet access

8. Authorizes SSH ingress on port 22 from any IP (0.0.0.0/0)

9. Launches EC2 instance with specified configuration

10. Waits for instance to reach 'running' state (with retries)

11. Retrieves public IP address and establishes SSH connection

B<Notes:>

All created resources are tagged with OpenQA job ID for easy identification and cleanup.
The test uses a /28 network (16 IPs) which provides sufficient addresses for basic testing scenarios.

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils;
use serial_terminal 'select_serial_terminal';
use utils qw(script_retry);
use sles4sap::aws_cli;
use sles4sap::crash;


sub run {
    my ($self) = @_;

    die('AWS is the only CSP supported for this test')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');

    select_serial_terminal;
    my $provider = $self->provider_factory();
    my $os_ver;
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        $os_ver = $provider->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os_ver = $provider->get_image_id();
    }
    assert_script_run('rm ~/.ssh/config');

    my $instance_id = crash_deploy_aws(
        region => get_var('PUBLIC_CLOUD_REGION'),
        image_name => $os_ver,
        # 679593333241 ( aws-marketplace )
        image_owner => get_var('PUBLIC_CLOUD_EC2_ACCOUNT_ID', '679593333241'),
        ssh_pub_key => $provider->ssh_key . ".pub",
        instance_type => get_var('PUBLIC_CLOUD_NEW_INSTANCE_TYPE'));

    my $ip_address = aws_get_ip_address(instance_id => $instance_id);
    my $ssh_cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user\@$ip_address";
    script_retry("$ssh_cmd hostnamectl", 90, delay => 15, retry => 12);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
}

1;
