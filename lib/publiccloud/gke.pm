# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Google Container Registry (GCR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://cloud.google.com/container-registry/docs/pushing-and-pulling

package publiccloud::gke;
use Mojo::Base 'publiccloud::k8s_provider';
use testapi;
use utils;

has provider_client => undef;

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("GKE");

    my $cluster = get_var("PUBLIC_CLOUD_K8S_CLUSTER", "qe-c-testing");
    my $zone = get_var("PUBLIC_CLOUD_ZONE", "europe-west4-a");
    assert_script_run("gcloud components install -q gke-gcloud-auth-plugin", 1200);
    my $getCredentialsCommand = sprintf("gcloud container clusters get-credentials %s --zone %s", $cluster, $zone);
    assert_script_run($getCredentialsCommand, 120);
}

=head2 delete_container_image

Clean a container image from the GCR
=cut

sub delete_container_image {
    my ($self, $tag) = @_;

    $tag //= $self->get_default_tag();
    record_info('INFO', "Deleting image $tag");
    my $full_name = $self->get_container_image_full_name($tag, "latest");
    assert_script_run("gcloud container images delete " . $full_name . " --quiet");
}

sub cleanup() {
    my ($self) = @_;

    $self->provider_client->cleanup();
}

sub destroy() {
    my ($self) = @_;

    $self->provider_client->destroy();
}

1;
