# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Testmodule to upload images to CSP
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "publiccloud::basetest";
use strict;
use warnings;
use testapi;
use utils;
use publiccloud::ec2;
use publiccloud::azure;
use publiccloud::gce;
use publiccloud::openstack;

sub run {
    my ($self) = @_;
    # Better use the root-console here so that the download progress can be monitored in openQA
    select_console("root-console");

    my $provider = $self->provider_factory();

    my $img_url = get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    my ($img_name) = $img_url =~ /([^\/]+)$/;

    if (my $img_id = $provider->find_img($img_name)) {
        record_info('Info', "Image $img_id already exists!");
        return;
    }

    # Download the given image via wget. Note that by default wget retries 20 times before giving up
    my $cmd = "wget --no-check-certificate --retry-connrefused --retry-on-host-error $img_url -O $img_name";
    # A generious timeout is required because downloading up to 30 GB (Azure images) can take more than an hour.
    my $rc = script_run("$cmd 2>&1 | tee download.txt", timeout => 120 * 60);
    if ($rc != 0) {
        # Check for 404 errors and make them better visible
        upload_logs("download.txt");
        # The log contains mostly the download progress bar. Crop the last 10 lines for better visibility
        my $output = script_output("tail -n 10 download.txt");
        record_info("wget failed with status code $rc", "$cmd\n\n$output");
        die "404 - Image not found" if ($output =~ "ERROR 404: Not Found");
        die "wget failed with return code $rc";
    }
    $provider->upload_img($img_name);
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Discussion

OpenQA script to upload images into public cloud. This test module is only
added if PUBLIC_CLOUD_IMAGE_LOCATION is set.

=head1 Configuration

=head2 PUBLIC_CLOUD_PROVIDER

The type of the CSP (e.g. AZURE, EC2, GOOGLE)

=head2 PUBLIC_CLOUD_IMAGE_LOCATION

The URL where the image gets downloaded from. The name of the image gets extracted
from this URL.

=head2 PUBLIC_CLOUD_KEY_ID

The CSP credentials key-id to used to access API.

=head2 PUBLIC_CLOUD_KEY_SECRET

The CSP credentials secret used to access API.

=head2 PUBLIC_CLOUD_REGION

The region to use. (default-azure: westeurope, default-ec2: eu-central-1, default-gcp: europe-west1)

=head2 PUBLIC_CLOUD_AZURE_TENANT_ID

This is B<only for azure> and used to create the service account file.

=cut
