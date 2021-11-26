# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Google Container Registry (GCR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://cloud.google.com/container-registry/docs/pushing-and-pulling

package publiccloud::gcr;
use Mojo::Base 'publiccloud::k8s_provider';
use testapi;
use utils;

# has security_token => undef;

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("GCR");
    $self->configure_docker();
}

=head2 push_container_image

Upload a container image to the GCR. Required parameter is the
name of the image, previously stored in the local registry. And
the tag (name) in the public cloud containers repository
Retrieves the full name of the uploaded image or die.
=cut

sub push_container_image {
    my ($self, $image, $tag) = @_;

    my $full_name = $self->get_container_image_full_name($tag, "latest");

    assert_script_run("docker tag $image $full_name");
    assert_script_run("docker push $full_name", 180);

    return $full_name;
}

=head2 delete_image

Delete a container image in the GCR
=cut

sub delete_image {
    my ($self, $tag) = @_;

    $tag //= $self->get_default_tag();
    record_info('INFO', "Deleting image $tag");
    my $full_name = $self->get_container_image_full_name($tag, "latest");
    assert_script_run("gcloud container images delete " . $full_name . " --quiet");
    return;
}

1;
