# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Pull and test several base images (alpine, openSUSE, debian, ubuntu, fedora, centos, ubi) for their base functionality
#          Log the test results in docker-3rd_party_images_log.txt
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use containers::common;
use containers::urls 'get_3rd_party_images';
use containers::container_images qw(test_3rd_party_image upload_3rd_party_images_logs);
use registration;
use Utils::Architectures;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;


    record_info "is_aarch64", is_aarch64;
    record_info "INFO", is_aarch64;

    if (is_aarch64) {
        record_info "INFO", "is_aarch64";
        script_run("echo 'is_aarch64'");
    }
    else {
        record_info "INFO", "NO is_aarch64";
        script_run("echo 'NO is_aarch64'");
    }

    script_run("echo 'Container base image tests:' > /var/tmp/podman-3rd_party_images_log.txt");
    my $engine = $self->containers_factory('podman');
    my $images = get_3rd_party_images();
    for my $image (@{$images}) {
        test_3rd_party_image($engine, $image);
    }
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    upload_3rd_party_images_logs('podman');
}

sub post_run_hook {
    upload_3rd_party_images_logs('podman');
}

1;
