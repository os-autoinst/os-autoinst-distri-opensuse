# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test podman installation and extended usage in a Kubic system
#    Cover the following aspects of podman:
#      * podman daemon can be started
#      * images can be searched on the default registry
#      * images can be pulled from the default registry
#      * local images can be listed
#      * containers can be spawned
#      * containers state can be saved to an image
#      * network is working inside of the containers
#      * containers can be stopped
#      * containers can be deleted
#      * images can be deleted
# Maintainer: qac team <qa-c@suse.de>

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use registration;
use containers::common;
use version_utils qw(is_sle is_leap is_jeos get_os_release);
use containers::utils;
use containers::container_images;
use containers::engine;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $dir    = "/root/DockerTest";
    my $podman = containers::engine::podman->new();
    my ($running_version, $sp, $host_distri) = get_os_release;

    install_podman_when_needed($host_distri);
    $podman->configure_insecure_registries();

    # Run basic tests for podman
    basic_container_tests(runtime => $podman->runtime);

    # Build an image from Dockerfile and test it
    build_and_run_image(runtime => $podman, base => 'registry.opensuse.org/opensuse/leap:latest');

    # Clean container
    $podman->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    script_run "podman version | tee /dev/$serialdev";
    script_run "podman info --debug | tee /dev/$serialdev";
    $self->SUPER::post_fail_hook;
}

1;
