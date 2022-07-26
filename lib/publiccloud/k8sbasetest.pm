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
use warnings;
use strict;
use utils qw(random_string);
use containers::k8s qw(install_kubectl);

=head2 init

Prepare the provider and install kubectl
=cut

sub init {
    my ($self, %args) = @_;

    $self->select_serial_terminal;
    install_kubectl();

    $args{provider} //= get_required_var('PUBLIC_CLOUD_PROVIDER');
    $args{service} //= $self->get_k8s_service_name($args{provider});

    $self->provider_factory(provider => $args{provider}, service => $args{service});
}

=head2 apply_manifest

Apply a kubernetes manifest
=cut

sub apply_manifest {
    my ($self, $manifest) = @_;

    my $path = sprintf('/tmp/%s.yml', random_string(32));

    script_output("echo -e '$manifest' > $path");
    upload_logs($path, failok => 1);

    assert_script_run("kubectl apply -f $path");
}

=head2 find_pods

Find pods using kubectl queries
=cut

sub find_pods {
    my ($self, $query) = @_;
    return script_output("kubectl get pods --no-headers -l $query -o custom-columns=':metadata.name'");
}

=head2 wait_for_job_complete

Wait until the job is complete
=cut

sub wait_for_job_complete {
    my ($self, $job) = @_;
    assert_script_run("kubectl wait --for=condition=complete --timeout=300s job/$job");
}

=head2 validate_log

Validates that the logs contains a text
=cut

sub validate_log {
    my ($self, $pod, $text) = @_;
    validate_script_output("kubectl logs $pod 2>&1", qr/$text/);
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
