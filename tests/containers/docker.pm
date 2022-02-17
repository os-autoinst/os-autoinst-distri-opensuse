# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker
# Summary: Test docker installation and extended usage
# - docker package can be installed
# - firewall is configured correctly
# - docker daemon can be started
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
    my ($self) = @_;
    $self->select_serial_terminal;

    my $sleep_time = 90 * get_var('TIMEOUT_SCALE', 1);
    my $dir = "/root/DockerTest";

    my $engine = $self->containers_factory('docker');
    test_seccomp();

    # Test the connectivity of Docker containers
    $engine->check_containers_connectivity();

    # Run basic runtime tests
    basic_container_tests(runtime => $engine->runtime);
    # Build an image from Dockerfile and run it
    build_and_run_image(runtime => $engine, dockerfile => 'Dockerfile.python3', base => registry_url('python', '3'));

    # Once more test the basic functionality
    runtime_smoke_tests(runtime => $engine);

    # Clean the container host
    $engine->cleanup_system_host();
}

1;
