# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for amazon connection and authentication
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::k8s_provider;
use Mojo::Base -base;
use testapi;
use mmapi 'get_current_job_id';
use publiccloud::gcp_client;

has resource_name => sub { get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm') };
has provider_client => undef;

sub init {
    my ($self, $service) = @_;
    die('The service must be specified') if (!$service);

    record_info("K8S Service", $service);

    if ($service =~ /ECR|EKS/) {
        $self->provider_client(
            publiccloud::aws_client->new(
                service => $service
            ));
    }
    elsif ($service =~ /GCR|GKE/) {
        $self->provider_client(
            publiccloud::gcp_client->new(
                service => $service
            ));
    }
    elsif ($service =~ /ACR|AKS/) {
        $self->provider_client(
            publiccloud::azure_client->new(
                service => $service
            ));
    }
    else {
        die("Invalid provider");
    }

    $self->provider_client->init();
}

=head2 get_container_registry_prefix

Get the full registry prefix URL (based on the account and region) to push container images on ECR.
=cut

sub get_container_registry_prefix {
    my ($self) = @_;
    return $self->provider_client->get_container_registry_prefix();
}

=head2 get_container_image_full_name

Returns the full name of the container image in ECR registry
C<tag> Tag of the container
=cut

sub get_container_image_full_name {
    my ($self, $tag) = @_;
    return $self->provider_client->get_container_image_full_name($tag);
}

=head2 get_default_tag

Returns a default tag for container images based of the current job id
=cut

sub get_default_tag {
    my ($self) = @_;
    return join('-', $self->resource_name, get_current_job_id());
}

=head2 configure_podman

Configure the podman to access the cloud provider registry
=cut

sub configure_podman {
    my ($self) = @_;
    $self->provider_client->configure_podman();
}

=head2 push_container_image

Upload a container image to the Provider Cotainer registry. 
Required parameter is the name of the image, previously stored 
in the local registry. And the tag (name) in the public cloud 
containers repository Retrieves the full name of the uploaded 
image or die.
=cut
sub push_container_image {
    my ($self, $image, $tag) = @_;

    my $full_name = $self->get_container_image_full_name($tag);

    assert_script_run("podman tag $image $full_name");
    assert_script_run("podman push --remove-signatures $full_name", 300);

    return $full_name;
}

1;
