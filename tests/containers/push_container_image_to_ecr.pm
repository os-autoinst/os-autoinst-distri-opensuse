# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Push a container image to the public cloud container registry
#
# Maintainer: Ivan Lausuch <ilausuch@suse.com>, qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use containers::urls 'get_suse_container_urls';

sub run {
    my ($self, $args) = @_;

    $self->select_serial_terminal;

    my ($untested_images, $released_images) = get_suse_container_urls();

    my $provider = $self->provider_factory(service => 'ECR');
    $self->{provider} = $provider;

    my $image = $untested_images->[0];
    my $tag = $provider->get_default_tag();
    $self->{tag} = $tag;

    record_info('Pull', "Pulling $image");
    assert_script_run("podman pull $image", 360);

    my $image_build = script_output("podman image inspect $image --format='{{ index .Config.Labels \"org.opencontainers.image.version\"}}'");
    record_info('Img version', $image_build);

    my $image_name = $provider->push_container_image($image, $tag);
    record_info('Registry', "Image successfully uploaded to ECR:\n$image_name\n" . script_output("podman inspect $image_name"));
}

sub post_fail_hook {
    my ($self) = @_;
    record_info('INFO', "Deleting image $self->tag");
    $self->{provider}->delete_image($self->tag);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
