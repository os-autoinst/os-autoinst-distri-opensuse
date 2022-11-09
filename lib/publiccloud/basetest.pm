# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for publiccloud tests
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::basetest;
use base 'opensusebasetest';
use testapi;
use publiccloud::azure;
use publiccloud::ec2;
use publiccloud::eks;
use publiccloud::ecr;
use publiccloud::gce;
use publiccloud::gke;
use publiccloud::gcr;
use publiccloud::acr;
use publiccloud::aks;
use publiccloud::openstack;
use publiccloud::noprovider;
use strict;
use warnings;

sub provider_factory {
    my ($self, %args) = @_;
    my $provider;

    die("Provider already initialized") if ($self->{provider});

    $args{provider} //= get_required_var('PUBLIC_CLOUD_PROVIDER');

    if (get_var('PUBLIC_CLOUD_INSTANCE_IP')) {
        $provider = publiccloud::noprovider->new();
    }
    elsif ($args{provider} eq 'EC2') {
        $args{service} //= 'EC2';

        if ($args{service} eq 'ECR') {
            $provider = publiccloud::ecr->new(
                region => get_var('PUBLIC_CLOUD_REGION', 'eu-central-1')
            );
        }
        elsif ($args{service} eq 'EKS') {
            $provider = publiccloud::eks->new(
                region => get_var('PUBLIC_CLOUD_REGION', 'eu-central-1')
            );
        }
        elsif ($args{service} eq 'EC2') {
            $provider = publiccloud::ec2->new();
        }
        else {
            die('Unknown service given');
        }

    }
    elsif ($args{provider} eq 'AZURE') {
        $args{service} //= 'AVM';
        if ($args{service} eq 'ACR') {
            $provider = publiccloud::acr->new(
                region => get_var('PUBLIC_CLOUD_REGION', 'westeurope'),
                subscription => get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID'),
                username => get_var('PUBLIC_CLOUD_USER', 'azureuser')
            );
        }
        elsif ($args{service} eq 'AKS') {
            $provider = publiccloud::aks->new();
        }
        elsif ($args{service} eq 'AVM') {
            $provider = publiccloud::azure->new();
        } else {
            die('Unknown service given');
        }
    }
    elsif ($args{provider} eq 'GCE') {
        $args{service} //= 'GCE';
        if ($args{service} eq 'GCR') {
            $provider = publiccloud::gcr->new();
        }
        elsif ($args{service} eq 'GKE') {
            $provider = publiccloud::gke->new();
        }
        elsif ($args{service} eq 'GCE') {
            $provider = publiccloud::gce->new();
        }
        else {
            die('Unknown service given');
        }
    }
    elsif ($args{provider} eq 'OPENSTACK') {
        $provider = publiccloud::openstack->new();
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
    return 1;
}

sub _cleanup {
    my ($self) = @_;
    die("Cleanup called twice!") if ($self->{cleanup_called});
    $self->{cleanup_called} = 1;

    eval { $self->cleanup(); } or bmwqemu::fctwarn("self::cleanup() failed -- $@");

    my $flags = $self->test_flags();
    # currently we have two cases when cleanup of image will be skipped:
    # 1. Calling module needs to have publiccloud_multi_module => 1 test flag
    # and not have fatal => 1. Job should not have result = 'fail'
    return if ($flags->{publiccloud_multi_module} && !($self->{result} eq 'fail' && $flags->{fatal}));
    # 2. Job should have PUBLIC_CLOUD_NO_CLEANUP defined and job should have result = 'fail'
    return if ($self->{result} eq 'fail' && get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE'));
    if ($self->{run_args} && $self->{run_args}->{my_provider}) {
        eval { $self->{run_args}->{my_provider}->cleanup($self->{run_args}); } or bmwqemu::fctwarn("provider::cleanup() failed -- $@");
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
