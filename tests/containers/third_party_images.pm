# SUSE's openQA tests
#
# Copyright 2022-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Pull and test several base images (alpine, openSUSE, debian, ubuntu, fedora, centos, ubi) for their base functionality
#          Log the test results in docker-3rd_party_images_log.txt
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::urls 'get_3rd_party_images';
use registration;

sub test_3rd_party_image {
    my ($runtime, $image) = @_;
    my $runtime_name = $runtime->runtime;
    record_info('IMAGE', "Testing $image with $runtime_name");
    test_container_image(image => $image, runtime => $runtime);
    script_run("echo 'OK: $runtime_name - $image:latest' >> /var/tmp/${runtime_name}-3rd_party_images_log.txt");
}

sub upload_3rd_party_images_logs {
    my $runtime = shift;
    # Rename for better visibility in Uploaded Logs
    if (script_run("mv /var/tmp/$runtime-3rd_party_images_log.txt /tmp/$runtime-3rd_party_images_log.txt") != 0) {
        record_info("No logs", "No logs found");
    } else {
        upload_logs("/tmp/$runtime-3rd_party_images_log.txt");
        script_run("rm /tmp/$runtime-3rd_party_images_log.txt");
    }
}

sub run {
    my ($self, $args) = @_;
    $self->{runtime} = $args->{runtime};

    select_serial_terminal;

    script_run("echo 'Container base image tests:' > /var/tmp/podman-3rd_party_images_log.txt");
    my $engine = $self->containers_factory($self->{runtime});
    my $images = get_3rd_party_images();
    for my $image (@{$images}) {
        test_3rd_party_image($engine, $image);
    }
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    upload_3rd_party_images_logs($self->{runtime});
}

sub post_run_hook {
    my ($self) = @_;
    upload_3rd_party_images_logs($self->{runtime});
}

1;
