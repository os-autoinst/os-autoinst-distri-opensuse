# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for publiccloud tests
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::k8sbasetest;
use Mojo::Base 'publiccloud::basetest';
use utils 'script_retry';
use testapi;
use serial_terminal 'select_serial_terminal';
use warnings;
use strict;
use utils qw(random_string);
use containers::k8s qw(install_kubectl apply_manifest wait_for_k8s_job_complete find_pods validate_pod_log);

=head2 init

Prepare the provider and install kubectl
=cut

sub init {
    my ($self, %args) = @_;

    select_serial_terminal;
    install_kubectl();

    $args{provider} //= get_required_var('PUBLIC_CLOUD_PROVIDER');
    $args{service} //= $self->get_k8s_service_name($args{provider});

    $self->provider_factory(provider => $args{provider}, service => $args{service});
}

=head2 get_k8s_service_name

Returns the name for the kubernetes service
=cut

sub get_k8s_service_name {
    my ($self, $provider) = @_;

    $provider //= get_required_var('PUBLIC_CLOUD_PROVIDER');

    if ($provider eq 'EC2') {
        return "EKS";
    }
    elsif ($provider eq 'GCE') {
        return "GKE";
    }
    elsif ($provider eq 'AZURE') {
        return "AKS";
    }
    else {
        die("Unknown provider $provider given");
    }
}

=head2 get_container_registry_service_name

Returns the name for the container registry based on the public provider
=cut

sub get_container_registry_service_name {
    my ($self, $provider) = @_;

    $provider //= get_required_var('PUBLIC_CLOUD_PROVIDER');

    if ($provider eq 'EC2') {
        return "ECR";
    }
    elsif ($provider eq 'GCE') {
        return "GCR";
    }
    elsif ($provider eq 'AZURE') {
        return "ACR";
    }
    else {
        die("Unknown provider $provider given");
    }
}

1;
