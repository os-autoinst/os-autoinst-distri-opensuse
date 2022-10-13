# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
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

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("GCR");
    $self->configure_podman();
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
