# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Azure Kubernetes Service (AKS)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

package publiccloud::aks;
use Mojo::Base 'publiccloud::k8s_provider';
use testapi;
use utils;

has provider_client => undef;

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("AKS");

    record_info('AKS', "Setting up credentials");

    my $cluster = get_var("PUBLIC_CLOUD_K8S_CLUSTER", "suse-qec-testing");
    my $resource_group = get_var("PUBLIC_CLOUD_AZURE_K8S_RESOURCE_GROUP", "openqa-upload");
    assert_script_run("az aks get-credentials --resource-group $resource_group --name $cluster", 120);
}

=head2 delete_container_image

Clean a container image from the ACR
=cut

sub delete_container_image {
    my ($self, $tag) = @_;

    assert_script_run(
        "az acr repository delete --yes --name " . $self->provider_client->container_registry . " --image " . $tag);
}

sub cleanup() {
    my ($self) = @_;

    $self->provider_client->cleanup();
}

1;
