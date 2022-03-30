# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test installation and running of the docker image from the registry for this snapshot
# This module is unified to run independented the host os.
# Maintainer: Fabian Vogt <fvogt@suse.com>, qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use containers::common;
use containers::container_images;
use containers::urls qw(get_suse_container_urls get_container_url_from_var);

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal();

    my $runtime = $args->{runtime};
    my $engine = $self->containers_factory($runtime);

    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE') && $runtime eq 'docker');

    # We may test either one specific image VERSION or comma-separated CONTAINER_IMAGE_VERSIONS
    my $versions = get_var('CONTAINER_IMAGE_VERSIONS', get_required_var('VERSION'));
    for my $version (split(/,/, $versions)) {
        my $images_to_test;
        # Get array of single image from CONTAINER_IMAGES_TO_TEST or from get_suse_container_urls()
        unless ($images_to_test = get_container_url_from_var('CONTAINER_IMAGE_TO_TEST')) {
            my ($untested_images, $released_images) = get_suse_container_urls(version => $version);
            $images_to_test = check_var('CONTAINERS_UNTESTED_IMAGES', '1') ? $untested_images : $released_images;
        }

        for my $iname (@{$images_to_test}) {
            record_info "IMAGE", "Testing image: $iname";
            test_container_image(image => $iname, runtime => $engine);
            test_rpm_db_backend(image => $iname, runtime => $engine);
            test_systemd_install(image => $iname, runtime => $engine);
            my $beta = $version eq get_var('VERSION') ? get_var('BETA', 0) : 0;
            test_opensuse_based_image(image => $iname, runtime => $engine, version => $version, beta => $beta) unless ($iname =~ /bci/);
        }
    }
    scc_restore_docker_image_credentials() if ($runtime eq 'docker');

    $engine->cleanup_system_host();
}

1;
