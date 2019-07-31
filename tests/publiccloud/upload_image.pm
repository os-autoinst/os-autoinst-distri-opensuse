# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $provider = $self->provider_factory();

    my $img_url    = get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    my ($img_name) = $img_url =~ /([^\/]+)$/;
    my $img_type   = get_var('PUBLIC_CLOUD_IMAGE_TYPE');

    if (my $img_id = $provider->find_img($img_name)) {
        record_info('Info', "Image $img_id already exists!");
        return;
    }

    assert_script_run("wget $img_url -O $img_name", timeout => 60 * 10);
    $provider->upload_img($img_name, $img_type);
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

=head2 PUBLIC_CLOUD_TENANT_ID

This is B<only for azure> and used to create the service account file.

=cut
