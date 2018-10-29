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
use testapi;
use utils;
use version_utils 'is_sle';
use registration 'add_suseconnect_product';
use publiccloud::ec2;
use publiccloud::azure;
use publiccloud::gce;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $provider = $self->{provider} = $self->provider_factory();
    $provider->init;

    my $img_url = get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    my ($img_name) = $img_url =~ /([^\/]+)$/;

    if (my $img_id = $provider->find_img($img_name)) {
        record_info('Info', "Image $img_name already exists!");
        set_var('PUBLIC_CLOUD_IMAGE_ID', $img_id);
        return;
    }

    assert_script_run("wget $img_url -O $img_name", timeout => 60 * 10);

    my $img_id = $provider->upload_img($img_name);

    set_var('PUBLIC_CLOUD_IMAGE_ID', $img_id);

    $provider->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;

    if ($self->{provider}) {
        $self->{provider}->cleanup();
    }
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
