# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Azure Container Registry (ACR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>

package publiccloud::acr;
use Mojo::Base 'publiccloud::k8s_provider';
use testapi;
use utils;

has security_token => undef;
has key_id => undef;
has key_secret => undef;
has subscription => undef;
has tenantid => undef;

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("ACR");
    $self->configure_docker();
}

=head2 push_container_image
Upload a container image to the ACR. Required parameter is the
name of the image, previously stored in the local registry. And
the tag (name) in the public cloud containers repository
Retrieves the full name of the uploaded image or die.
=cut
sub push_container_image {
    my ($self, $image, $tag) = @_;

    my $region //= $self->region;
    my $full_name_prefix = $self->get_container_registry_prefix();
    my $full_name = $self->get_container_image_full_name($tag);

    assert_script_run("docker tag $image $full_name");
    assert_script_run("docker push $full_name", 180);

    return $full_name;
}

=head2 delete_image
Delete a ACR image
=cut
sub delete_image {
    my ($self, $tag) = @_;
    $tag //= $self->get_default_tag();
    record_info('INFO', "Deleting image $tag");
    assert_script_run(
        "az acr repository delete --yes --name " . $self->provider_client->container_registry . " --image " . $tag);
    return;
}

sub cleanup() {
    my ($self) = @_;
    $self->provider_client->cleanup();
}

1;
