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
    else {
        die('Unknown PUBLIC_CLOUD_PROVIDER given');
    }
}

1;
