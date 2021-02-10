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
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(get_os_release check_os_release);

sub run {
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;

    install_buildah_when_needed($host_distri);
    install_podman_when_needed($host_distri);
    allow_selected_insecure_registries(runtime => 'podman');
    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));

    for my $iname (@{$image_names}) {
        test_container_image(image => $iname, runtime => 'buildah');
        if (check_os_release('suse', 'PRETTY_NAME')) {
            # sle15-working-container is the default name given to a container. it is created in test_container_image
            test_opensuse_based_image(image => 'sle15-working-container', runtime => 'buildah');
            allow_selected_insecure_registries(runtime => 'podman');
        }
    }
    scc_restore_docker_image_credentials();
    clean_container_host(runtime => 'podman');
    clean_container_host(runtime => 'buildah');
}

1;
