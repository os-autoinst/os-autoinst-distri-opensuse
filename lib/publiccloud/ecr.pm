# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
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
    $self->configure_podman();
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
