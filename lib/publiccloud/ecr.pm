# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Amazon Elastic Container Registry (ECR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

package publiccloud::ecr;
use Mojo::Base 'publiccloud::k8s_provider';
use testapi;
use utils;

has security_token => undef;

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("ECR");
}

=head2 push_container_image
Upload a container image to the ECR. Required parameter is the
name of the image, previously stored in the local registry. And
the tag (name) in the public cloud containers repository
Retrieves the full name of the uploaded image or die.
=cut
sub push_container_image {
    my ($self, $image, $tag) = @_;

    my $region //= $self->region;
    my $full_name_prefix = $self->get_container_registry_prefix();
    my $full_name = $self->get_container_image_full_name($tag);

    assert_script_run(
        "aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $full_name_prefix");
    assert_script_run("docker tag $image $full_name");
    assert_script_run("docker push $full_name", 180);

    return $full_name;
}

=head2 delete_image
Delete a ECR image
=cut
sub delete_image {
    my ($self, $tag) = @_;
    assert_script_run(
        "aws ecr batch-delete-image --repository-name " . $self->container_registry . " --image-ids imageTag=" . $tag);
    return;
}

sub cleanup() {
    my ($self) = @_;
    $self->provider_client->cleanup();
}

1;
