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
use version_utils qw(get_os_release check_os_release);

sub run {
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $buildah = containers::runtime->new(engine => 'buildah');

    install_buildah_when_needed($host_distri);
    install_podman_when_needed($host_distri);
    allow_selected_insecure_registries($buildah);
    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));

    for my $iname (@{$image_names}) {
        record_info 'testing image', $iname;
        test_container_image($buildah, image => $iname);
        if (check_os_release('suse', 'PRETTY_NAME')) {
            # Use container which it is created in test_container_image
            # Buildah default name is conducted by <image-name>-working-container
            my ($prefix_img_name) = $iname =~ /([^\/:]+)(:.+)?$/;
            record_info $prefix_img_name;
            test_opensuse_based_image($buildah, image => "${prefix_img_name}-working-container");
            # Due to the steps from the test_opensuse_based_image previously,
            # the image has been committed as refreshed
            test_containered_app(containers::runtime->new(engine => 'podman'), buildah => 1, dockerfile => 'Dockerfile.suse', base => 'refreshed');
        }
    }
    scc_restore_docker_image_credentials();
    $buildah->cleanup_system_host();
}

1;
