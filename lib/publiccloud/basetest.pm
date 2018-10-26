# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for publiccloud tests
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::basetest;
use base 'opensusebasetest';
use testapi;
use publiccloud::azure;
use publiccloud::ec2;
use publiccloud::gce;

sub provider_factory {
    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        return publiccloud::ec2->new(
            key_id     => get_required_var('PUBLIC_CLOUD_KEY_ID'),
            key_secret => get_required_var('PUBLIC_CLOUD_KEY_SECRET'),
            region     => get_var('PUBLIC_CLOUD_REGION', 'eu-central-1')
        );

    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        return publiccloud::azure->new(
            key_id       => get_required_var('PUBLIC_CLOUD_KEY_ID'),
            key_secret   => get_required_var('PUBLIC_CLOUD_KEY_SECRET'),
            region       => get_var('PUBLIC_CLOUD_REGION', 'westeurope'),
            tenantid     => get_required_var('PUBLIC_CLOUD_TENANT_ID'),
            subscription => get_required_var('PUBLIC_CLOUD_SUBSCRIPTION_ID')
        );
    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'GCE')) {
        return publiccloud::gce->new(
            account             => get_required_var('PUBLIC_CLOUD_ACCOUNT'),
            service_acount_name => get_required_var('PUBLIC_CLOUD_SERVICE_ACCOUNT'),
            project_id          => get_required_var('PUBLIC_CLOUD_PROJECT_ID'),
            private_key_id      => get_required_var('PUBLIC_CLOUD_KEY_ID'),
            private_key         => get_required_var('PUBLIC_CLOUD_KEY'),
            client_id           => get_required_var('PUBLIC_CLOUD_CLIENT_ID'),
            region              => get_var('PUBLIC_CLOUD_REGION', 'europe-west1-b')
        );
    }
    else {
        die('Unknown PUBLIC_CLOUD_PROVIDER given');
    }
}

sub get_image_id {
    my ($provider) = @_;

    my $image_id = get_var('PUBLIC_CLOUD_IMAGE_ID');
    $image_id //= $provider->find_img(get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    die('Missing valid image_id') unless ($image_id);
    return $image_id;
}

1;
