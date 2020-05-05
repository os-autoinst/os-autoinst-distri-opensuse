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
use strict;
use warnings;

sub provider_factory {
    my ($self) = @_;
    my $provider;

    die("Provider already initialized") if ($self->{provider});

    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        $provider = publiccloud::ec2->new(
            key_id     => get_var('PUBLIC_CLOUD_KEY_ID'),
            key_secret => get_var('PUBLIC_CLOUD_KEY_SECRET'),
            region     => get_var('PUBLIC_CLOUD_REGION', 'eu-central-1'),
            username   => get_var('PUBLIC_CLOUD_USER', 'ec2-user')
        );

    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        $provider = publiccloud::azure->new(
            key_id       => get_var('PUBLIC_CLOUD_KEY_ID'),
            key_secret   => get_var('PUBLIC_CLOUD_KEY_SECRET'),
            region       => get_var('PUBLIC_CLOUD_REGION', 'westeurope'),
            tenantid     => get_var('PUBLIC_CLOUD_TENANT_ID'),
            subscription => get_var('PUBLIC_CLOUD_SUBSCRIPTION_ID'),
            username     => get_var('PUBLIC_CLOUD_USER', 'azureuser')
        );
    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'GCE')) {
        $provider = publiccloud::gce->new(
            account             => get_var('PUBLIC_CLOUD_ACCOUNT'),
            service_acount_name => get_var('PUBLIC_CLOUD_SERVICE_ACCOUNT'),
            project_id          => get_var('PUBLIC_CLOUD_PROJECT_ID'),
            private_key_id      => get_var('PUBLIC_CLOUD_KEY_ID'),
            private_key         => get_var('PUBLIC_CLOUD_KEY'),
            client_id           => get_var('PUBLIC_CLOUD_CLIENT_ID'),
            region              => get_var('PUBLIC_CLOUD_REGION', 'europe-west1-b'),
            storage_name        => get_var('PUBLIC_CLOUD_STORAGE', 'openqa-storage'),
            username            => get_var('PUBLIC_CLOUD_USER', 'susetest')
        );
    }
    else {
        die('Unknown PUBLIC_CLOUD_PROVIDER given');
    }

    $provider->init();
    $self->{provider} = $provider;
    return $provider;
}

sub cleanup {
    # to be overridden by tests
    return;
}

sub _cleanup {
    my ($self) = @_;
    die("Cleanup called twice!") if ($self->{cleanup_called});
    $self->{cleanup_called} = 1;

    eval { $self->cleanup(); } or bmwqemu::fctwarn($@);

    my $flags = $self->test_flags();
    # currently we have two cases when cleanup of image will be skipped:
    # 1. Calling module needs to have publiccloud_multi_module => 1 test flag
    # and not have fatal => 1. Job should not have result = 'fail'
    return if ($flags->{publiccloud_multi_module} && !($self->{result} eq 'fail' && $flags->{fatal}));
    # 2. Job should have PUBLIC_CLOUD_NO_CLEANUP defined and job should have result = 'fail'
    return if ($self->{result} eq 'fail' && get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE'));
    if ($self->{provider}) {
        eval { $self->{provider}->cleanup(); } or bmwqemu::fctwarn($@);
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->_cleanup() unless $self->{cleanup_called};
}

sub post_run_hook {
    my ($self) = @_;
    $self->_cleanup() unless $self->{cleanup_called};
}

1;
