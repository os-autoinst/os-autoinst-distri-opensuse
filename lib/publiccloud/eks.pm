# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Amazon Elastic Container Registry (ECR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

package publiccloud::eks;
use Mojo::Base 'publiccloud::k8s_provider';
use testapi;
use utils;

has provider_client => undef;

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("EKS");

    my $cluster = get_required_var("PUBLIC_CLOUD_K8S_CLUSTER");
    assert_script_run("aws eks update-kubeconfig --name $cluster", 120);
}

=head2 delete_container_image

Clean a container image from the ECR
=cut
sub delete_container_image {
    my ($self, $tag) = @_;

    assert_script_run("aws ecr batch-delete-image --repository-name "
          . $self->provider_client->container_registry
          . " --image-ids imageTag="
          . $tag);
}

sub cleanup() {
    my ($self) = @_;

    $self->provider_client->cleanup();
}

1;
