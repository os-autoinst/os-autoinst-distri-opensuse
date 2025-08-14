# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Testmodule to upload images to CSP
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "publiccloud::basetest";
use testapi;
use utils;
use publiccloud::ec2;
use publiccloud::azure;
use publiccloud::gce;
use publiccloud::openstack;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_jeos);

sub run {
    my ($self, $args) = @_;
    # Better use the root-console here so that the download progress can be monitored in openQA
    select_serial_terminal();

    my $provider = $self->provider_factory();
    $args->{my_provider} = $provider;

    my $img_url = get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    my ($img_name) = $img_url =~ /([^\/]+)$/;

    if (my $img_id = $provider->find_img($img_name)) {
        record_info('Info', "Image $img_id already exists!");
        return;
    }

    # Download the given image via wget. Note that by default wget retries 20 times before giving up
    my $wget_cmd = "wget -q --server-response --no-check-certificate --retry-connrefused --retry-on-host-error";
    my $cmd = "$wget_cmd $img_url -O $img_name";
    my $cmd_sha256 = "$wget_cmd $img_url.sha256 -O $img_name.sha256";
    # A generous timeout is required because downloading up to 30 GB (Azure images) can take more than an hour.
    my $rc = script_run("(set -o pipefail && $cmd 2>&1 | tee download.txt)", timeout => 120 * 60);
    if ($rc != 0) {
        # Check for 404 errors and make them better visible
        upload_logs("download.txt");
        # The log contains mostly the download progress bar. Crop the last 10 lines for better visibility
        my $output = script_output("tail -n 10 download.txt");
        record_info("wget failed with status code $rc", "$cmd\n\n$output");
        die "404 - Image not found" if ($output =~ "ERROR 404: Not Found");
        die "wget failed with return code $rc";
    }

    # IBS sync does not pull checksum file for JeOS Cloud image
    unless (is_jeos) {
        assert_script_run $cmd_sha256;
        assert_script_run "sha256sum -c $img_name.sha256";
    }

    $provider->upload_img($img_name);
}

sub finalize {
    # because it is upload_img we don't have instance created hence clasical cleanup does not make sense
    #TODO: nevertheless we can implement here upload of logs related to image upload process per provider
}

sub test_flags {
    # in case of migration this is not single module so we need to skip cleanup
    return {fatal => 1, publiccloud_multi_module => 1} if (get_var('PUBLIC_CLOUD_MIGRATION'));
    return {fatal => 1};
}

1;

=head1 Discussion

OpenQA script to upload images into public cloud. This test module is only
added if PUBLIC_CLOUD_IMAGE_LOCATION is set.
