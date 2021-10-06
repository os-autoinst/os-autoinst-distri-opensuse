# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Amazon Elastic Container Registry (ECR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

package publiccloud::eks;
use Mojo::Base 'publiccloud::aws';
use testapi;

=head2 push_container_image
Upload a container image to the ECR. Required parameter is the
name of the image, previously stored in the local registry. And
the tag (name) in the public cloud containers repository
Retrieves the full name of the uploaded image or die.
=cut
sub push_container_image {
    my ($self, $image, $tag) = @_;

    my $region     //= $self->region();
    my $repository //= get_var("PUBLIC_CLOUD_CONTAINER_IMAGES_REPO", 'suse-qec-testing');
    my $aws_account_id   = $self->{aws_account_id};
    my $full_name_prefix = "$aws_account_id.dkr.ecr.$region.amazonaws.com";
    my $full_name        = "$full_name_prefix/$repository:$tag";

    $self->{repository} = $repository;
    $self->{tag}        = $tag;

    assert_script_run("aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $full_name_prefix");
    assert_script_run("docker tag $image $full_name");
    assert_script_run("docker push $full_name", 180);
    return $full_name;
}

sub cleanup {
    my $self = shift;
    assert_script_run("aws ecr batch-delete-image --repository-name " . $self->{repository} . " --image-ids imageTag=" . $self->{tag});
    $self->SUPER::cleanup();
    return;
}

1;
