# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker
# Summary: Pull and test several base images (alpine, openSUSE, debian, ubuntu, fedora, centos, ubi) for their base functionality
#          Log the test results in docker-3rd_party_images_log.txt
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(containers::basetest);
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use containers::common;
use containers::urls 'get_3rd_party_images';
use containers::container_images qw(test_3rd_party_image upload_3rd_party_images_logs);
use registration;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $engine = $self->get_instance($self->{run_args});

    my ($running_version, $sp, $host_distri) = get_os_release;

    install_docker_when_needed($host_distri) if $engine->runtime eq 'docker';
    install_podman_when_needed($host_distri) if $engine->runtime eq 'podman';

    script_run("echo 'Container base image tests:' > /var/tmp/docker-3rd_party_images_log.txt");
    # In SLE we need to add the Containers module
    $engine->configure_insecure_registries();
    my $images = get_3rd_party_images();
    for my $image (@{$images}) {
        test_3rd_party_image($engine, $image);
    }
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    my $factory = containers::engine::Factory->new();
    my $engine = $factory->get_instance($self->{run_args});
    upload_3rd_party_images_logs($engine->runtime);
}

sub post_run_hook {
    my ($self) = @_;
    my $factory = containers::engine::Factory->new();
    my $engine = $factory->get_instance($self->{run_args});
    upload_3rd_party_images_logs($engine->{runtime});
}

1;
