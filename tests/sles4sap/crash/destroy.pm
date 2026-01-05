# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Public Cloud - Resource Cleanup
# This module deletes resources from cloud:
# - Free up cloud resources
# - Avoid additional cost
# - Clean up the environment
# It's also implemented as a post_fail_hook to ensure resources
# are deleted even if a test module fails.

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::crash;

sub run {
    my ($self) = @_;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $region = get_required_var('PUBLIC_CLOUD_REGION');

    select_serial_terminal;
    if ($provider eq 'AZURE') {
        crash_destroy_azure();
    }
    elsif ($provider eq 'EC2') {
        crash_destroy_aws(region => $region);
    }
    elsif ($provider eq 'GCE') {
        crash_destroy_gcp(region => $region, zone => $region . '-' . get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE'));
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
