# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: buildah
# Summary: building OCI-compatible sle base images with buildah.
# - install buildah
# - create and run container
# - build image with service and test connectivity
# - cleanup system (images, containers)
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_suse_container_urls';
use version_utils qw(get_os_release check_os_release is_sle);
use containers::engine;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my ($running_version, $sp, $host_distri) = get_os_release;

    install_buildah_when_needed($host_distri);
    install_podman_when_needed($host_distri);
    my $podman  = containers::engine::podman->new();
    my $buildah = containers::engine::buildah->new();
    $podman->configure_insecure_registries();
    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));

    # We may test either one specific image VERSION or comma-separated CONTAINER_IMAGES
    my $versions = get_var('CONTAINER_IMAGE_VERSIONS', get_required_var('VERSION'));
    for my $version (split(/,/, $versions)) {
        my ($untested_images, $released_images) = get_suse_container_urls(version => $version);
        my $images_to_test = check_var('CONTAINERS_UNTESTED_IMAGES', '1') ? $untested_images : $released_images;
        for my $iname (@{$images_to_test}) {
            record_info "IMAGE", "Testing image: $iname";
            test_container_image(image => $iname, runtime => $buildah);
            if (check_os_release('suse', 'PRETTY_NAME')) {
                # Use container which it is created in test_container_image
                # Buildah default name is conducted by <image-name>-working-container
                my ($prefix_img_name) = $iname =~ /([^\/:]+)(:.+)?$/;
                my $beta = $version eq get_var('VERSION') ? get_var('BETA', 0) : 0;
                test_opensuse_based_image(image => "${prefix_img_name}-working-container", runtime => $buildah, version => $version, beta => $beta);
                # Due to the steps from the test_opensuse_based_image previously,
                # the image has been committed as refreshed
                build_and_run_image(runtime => $podman, builder => $buildah, base => $iname) unless is_unreleased_sle;
                $podman->cleanup_system_host(0);
                $buildah->cleanup_system_host();
            }
        }
    }
    scc_restore_docker_image_credentials();
}

1;
