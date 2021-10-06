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
use mmapi 'get_current_job_id';

sub run {
    my ($self, $args) = @_;

    $self->select_serial_terminal;

    my ($untested_images, $released_images) = get_suse_container_urls();

    my $provider = $self->provider_factory();
    my $image    = $untested_images->[0];
    my $tag      = join('-', get_var('PUBLIC_CLOUD_RESOURCE_NAME'), get_current_job_id());
    assert_script_run("docker pull $image", 360);
    $provider->push_container_image($image, $tag);
}

1;
