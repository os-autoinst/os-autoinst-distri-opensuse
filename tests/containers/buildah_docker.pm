# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
use containers::runtime;

sub run {
    my ($running_version, $sp, $host_distri) = get_os_release;

    install_buildah_when_needed($host_distri);
    install_docker_when_needed($host_distri);
    my $docker  = containers::runtime::docker->new();
    my $buildah = containers::runtime::buildah->new();
    allow_selected_insecure_registries(runtime => $docker);
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
                test_opensuse_based_image(image => "${prefix_img_name}-working-container", runtime => $buildah, version => $version);
                # Due to the steps from the test_opensuse_based_image previously,
                # the image has been committed as refreshed
                build_and_run_image(runtime => $docker, builder => $buildah, base => 'refreshed');
            }
        }
    }
    scc_restore_docker_image_credentials();
    $docker->cleanup_system_host(0);
    $buildah->cleanup_system_host();
}

1;
