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

    diag('Public Cloud _cleanup: $flags->{publiccloud_multi_module}=' . $flags->{publiccloud_multi_module}) if ($flags->{publiccloud_multi_module});
    diag('Public Cloud _cleanup: $flags->{fatal}=' . $flags->{fatal}) if ($flags->{fatal});
    diag('Public Cloud _cleanup: $self->{result}=' . $self->{result}) if ($self->{result});
    diag('Public Cloud _cleanup: $self->{run_args}') if ($self->{run_args});
    diag('Public Cloud _cleanup: $self->{provider}') if ($self->{provider});

    # currently we have two cases when cleanup of image will be skipped:
    # 1. Job should have 'PUBLIC_CLOUD_NO_CLEANUP' variable and result == 'fail'
    return if ($self->{result} && $self->{result} eq 'fail' && get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE'));
    diag('Public Cloud _cleanup: 1st check passed.');

    # 2. Test module needs to have 'publiccloud_multi_module' and should not have 'fatal' flags and 'fail' result
    if ($flags->{publiccloud_multi_module}) {
        diag('Public Cloud _cleanup: Test has `publiccloud_multi_module` flag.');
        return unless ($flags->{fatal} && $self->{result} && $self->{result} eq 'fail');
    } else {
        diag('Public Cloud _cleanup: Test does not have `publiccloud_multi_module` flag.');
    }
    diag('Public Cloud _cleanup: 2nd check passed.');

    # For maintenance, we need $self->run_args and $self->run_args->my_provider
    #  otherwise we need just $self->provider
    if (($self->{run_args} && $self->{run_args}->{my_provider}) || $self->{provider}) {
        diag('Public Cloud _cleanup: Ready for provider cleanup.');
        if (get_var('PUBLIC_CLOUD_QAM')) {
            eval { $self->{run_args}->{my_provider}->cleanup($self->{run_args}); } or bmwqemu::fctwarn("provider::cleanup() failed -- $@");
        } else {
            eval { $self->{provider}->cleanup(); } or bmwqemu::fctwarn("provider::cleanup() failed -- $@");
        }
        diag('Public Cloud _cleanup: The provider cleanup finished.');
    } else {
        diag('Public Cloud _cleanup: Not ready for provider cleanup.');
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
