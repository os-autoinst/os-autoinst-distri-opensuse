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
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::container_images;
use containers::urls qw(get_image_uri);
use db_utils qw(push_image_data_to_db);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal();

    my $runtime = $args->{runtime};
    my $engine = $self->containers_factory($runtime);

    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE') && $runtime eq 'docker');

    # We may test either one specific image VERSION or comma-separated CONTAINER_IMAGE_VERSIONS
    my $versions = get_var('CONTAINER_IMAGE_VERSIONS', get_required_var('VERSION'));
    for my $version (split(/,/, $versions)) {
        my $image = get_image_uri(version => $version);

        if (get_var('IMAGE_STORE_DATA')) {
            # If wanted, push image information to the DB
            script_retry("$runtime pull -q $image", timeout => 300, delay => 60, retry => 3);
            my $size_b = script_output("$engine inspect --format \"{{.VirtualSize}}\" $image");
            my $size_mb = $size_b / 1000000;
            push_image_data_to_db('containers', $image, $size_mb, flavor => 'base', type => 'VirtualSize');
        }

        record_info "IMAGE", "Testing image: $image Version: $version";
        test_container_image(image => $image, runtime => $engine);
        test_rpm_db_backend(image => $image, runtime => $engine);
        test_systemd_install(image => $image, runtime => $engine);
        my $beta = $version eq get_var('VERSION') ? get_var('BETA', 0) : 0;
        test_opensuse_based_image(image => $image, runtime => $engine, version => $version, beta => $beta) unless ($image =~ /bci/);
    }
    scc_restore_docker_image_credentials() if ($runtime eq 'docker');

    $engine->cleanup_system_host();
}

1;
