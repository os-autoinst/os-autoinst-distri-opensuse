# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: docker
# Summary: Test installation and running of the docker image from the registry for this snapshot.
# This module is unified to run independented the host os.
# - if on SLE, enable internal registry
# - load image
# - run container
# - run some zypper commands with zypper-decker if is sle/opensuse
# - try to run a single cat command if not sle/opensuse
# - commit the image
# - remove the container, run it again and verify that the new image works
# Maintainer: Pavel Dostál <pdostal@suse.cz>, qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_suse_container_urls';
use version_utils qw(get_os_release check_os_release is_tumbleweed);
use containers::engine;

sub run {
    my $self = shift;
    $self->select_serial_terminal();

    my ($running_version, $sp, $host_distri) = get_os_release;
    my $engine = containers::engine::docker->new();

    install_docker_when_needed($host_distri);
    $engine->configure_insecure_registries();
    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));

    # We may test either one specific image VERSION or comma-separated CONTAINER_IMAGE_VERSIONS
    my $versions = get_var('CONTAINER_IMAGE_VERSIONS', get_required_var('VERSION'));
    for my $version (split(/,/, $versions)) {
        my ($untested_images, $released_images) = get_suse_container_urls(version => $version);
        my $images_to_test = check_var('CONTAINERS_UNTESTED_IMAGES', '1') ? $untested_images : $released_images;
        for my $iname (@{$images_to_test}) {
            record_info "IMAGE", "Testing image: $iname";
            test_container_image(image => $iname, runtime => $engine);
            test_rpm_db_backend(image => $iname, runtime => $engine);
            my $beta = $version eq get_var('VERSION') ? get_var('BETA', 0) : 0;
            test_opensuse_based_image(image => $iname, runtime => $engine, version => $version, beta => $beta);
        }
    }
    scc_restore_docker_image_credentials();
    $engine->cleanup_system_host();
}

1;
