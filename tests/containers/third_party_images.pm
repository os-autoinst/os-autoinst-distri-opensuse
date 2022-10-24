# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Pull and test several base images (alpine, openSUSE, debian, ubuntu, fedora, centos, ubi) for their base functionality
#          Log the test results in docker-3rd_party_images_log.txt
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::urls 'get_3rd_party_images';
use containers::container_images qw(test_3rd_party_image upload_3rd_party_images_logs);
use registration;

sub run {
    my ($self, $args) = @_;
    $self->{runtime} = $args->{runtime};

    select_serial_terminal;

    script_run("echo 'Container base image tests:' > /var/tmp/podman-3rd_party_images_log.txt");
    my $engine = $self->containers_factory($self->{runtime});
    my $images = get_3rd_party_images();
    for my $image (@{$images}) {
        test_3rd_party_image($engine, $image);
    }
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    upload_3rd_party_images_logs($self->{runtime});
}

sub post_run_hook {
    my ($self) = @_;
    upload_3rd_party_images_logs($self->{runtime});
}

1;
