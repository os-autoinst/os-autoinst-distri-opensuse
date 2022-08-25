# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker/podman engine
# Summary: Test docker/podman installation and extended usage
# - docker/podman package can be installed
# - firewall is configured correctly
# - docker daemon can be started (if docker runtime)
# - images can be searched on the Docker Hub
# - images can be pulled from the Docker Hub
# - local images can be listed (with and without tag)
# - containers can be run and created
# - containers state can be saved to an image
# - network is working inside of the containers
# - containers can be stopped
# - containers can be deleted
# - images can be deleted
# - build a docker image
# - attach a volume
# - expose a port
# - test networking outside of host
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use containers::common;
use containers::utils;
use containers::container_images;

sub run {
    my ($self, $args) = @_;
    die('You must define a engine') unless ($args->{runtime});
    $self->{runtime} = $args->{runtime};
    $self->select_serial_terminal;

    my $dir = "/root/DockerTest";

    my $engine = $self->containers_factory($self->{runtime});
    test_seccomp() if ($self->{runtime} eq 'docker');

    # Test the connectivity of Docker containers
    check_containers_connectivity($engine);

    # Run basic runtime tests
    basic_container_tests(runtime => $self->{runtime});
    # Build an image from Dockerfile and run it
    build_and_run_image(runtime => $engine, dockerfile => 'Dockerfile.python3', base => registry_url('python', '3'));

    # Once more test the basic functionality
    runtime_smoke_tests(runtime => $engine);

    # Smoke test for engine search
    test_search_registry($engine);

    # Clean the container host
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    if ($self->{runtime} eq 'podman') {
        select_console 'log-console';
        script_run "podman version | tee /dev/$serialdev";
        script_run "podman info --debug | tee /dev/$serialdev";
    }
    $self->SUPER::post_fail_hook;
}

1;

