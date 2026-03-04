# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: This module is responsible for creating all necessary GCP resources:
# - VPC Network
# - Subnet
# - Firewall rule (SSH)
# - External IP
# - VM instance
# It saves VM public IP and SSH command into job variables

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils;
use serial_terminal 'select_serial_terminal';
use sles4sap::crash;

sub run {
    my ($self) = @_;

    die('GCE is the only CSP supported for this test')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'GCE');

    select_serial_terminal;
    my $provider = $self->provider_factory();

    assert_script_run('rm -f ~/.ssh/config');

    my $region = get_required_var('PUBLIC_CLOUD_REGION');
    crash_deploy_gcp(
        region => $region,
        availability_zone => get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE'),
        project => get_required_var('PUBLIC_CLOUD_GOOGLE_PROJECT_ID'),
        image_name => $provider->get_image_id() =~ s/.*\///r,
        image_project => get_required_var('PUBLIC_CLOUD_IMAGE_PROJECT'),
        machine_type => get_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'n1-standard-2'),
        ssh_pub_key => $provider->ssh_key . '.pub');
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    crash_destroy_gcp(
        availability_zone => get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE'),
        region => get_required_var('PUBLIC_CLOUD_REGION'));
    $self->SUPER::post_fail_hook;
}

1;

