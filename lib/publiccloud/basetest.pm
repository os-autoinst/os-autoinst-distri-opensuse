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
    # non-destructive cleanup for test module started by post_run_hook
    # primary for log collection | restore clean state after test module
    # can and be called after each module run
    return 1;
}

sub destroy {
    # to be overridden by tests
    # destructive routine in post_fail_hook | last module of test
    return 1;
}

sub _destroy {
    my ($self) = @_;
    # run module overriden destroy
    eval { $self->destroy(); } or bmwqemu::fctwarn("self::destroy() failed -- $@");
    # run provider destroy
    if ($self->{run_args} && $self->{run_args}->{my_provider}) {
        eval { $self->{run_args}->{my_provider}->destroy($self->{run_args}); } or bmwqemu::fctwarn("provider::destroy() failed -- $@");
    }
}

sub _cleanup {
    my ($self) = @_;
    # run module overriden cleanup
    eval { $self->cleanup(); } or bmwqemu::fctwarn("self::cleanup() failed -- $@");
    # run provider cleanup
    if ($self->{run_args} && $self->{run_args}->{my_provider}) {
        eval { $self->{run_args}->{my_provider}->cleanup($self->{run_args}); } or bmwqemu::fctwarn("provider::cleanup() failed -- $@");
    }
}

sub post_fail_hook {
    my ($self) = @_;
    my $flags = $self->test_flags();
    # run cleanup before destroy
    $self->_cleanup();
    # run full destroy if test is marked as fatal
    # and if PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE isn't defined
    return if get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE');
    $self->_destroy() if $flags->{fatal};
}

sub post_run_hook {
    my ($self) = @_;
    my $flags = $self->test_flags();
    $self->_cleanup();
    # run destroy if test is marked as last
    # beware after this pc instance is destroyed
    $self->_destroy if $flags->{last};
}

1;
