# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Push a container image to the Google Cloud Registry
#
# Maintainer: Ivan Lausuch <ilausuch@suse.com>, qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use containers::urls 'get_image_uri';

sub run {
    my ($self, $args) = @_;

    $self->select_serial_terminal;

    my $provider = $self->provider_factory(service => 'GCR');

    my $image = get_image_uri();
    my $tag = $provider->get_default_tag();

    record_info('Pull', "Pulling $image");
    assert_script_run("podman pull $image", 360);

    my $image_build_format = '{{ index .Config.Labels "org.opencontainers.image.version"}}';
    my $image_build = script_output("podman image inspect $image --format='$image_build_format'");
    record_info('Img version', $image_build);

    my $image_name = $provider->push_container_image($image, $tag);
    record_info('Registry',
        "Image successfully uploaded to GCR:\n$image_name\n" . script_output("podman inspect $image_name"));
}

sub post_fail_hook {
    my ($self) = @_;
    $self->{provider}->delete_image();
}

sub post_run_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
