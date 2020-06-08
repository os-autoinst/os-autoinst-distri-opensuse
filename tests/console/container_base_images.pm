# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Pull and test several base images (alpine, openSUSE, debian, ubuntu, fedora, centos) for their base functionality
#          Log the test results in container_base_images.txt
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use containers::common;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    # Define general test images. Add your docker- or podman-only images here as well if needed
    my @images        = ('alpine', 'opensuse/leap', 'opensuse/tumbleweed', 'debian', 'ubuntu', 'centos', 'fedora');
    my @docker_images = ();                                                                                           # Add Docker-only images here
    my @podman_images = ();                                                                                           # Add Podman-only images here

    script_run('echo "Container base image tests:" > /var/tmp/container_base_images_log.txt');
    # Run docker tests
    if (check_var("SKIP_DOCKER_IMAGE_TESTS", 1)) {
        record_info("Skip Docker", "Docker image tests skipped");
        script_run("echo 'INFO: Docker image tests skipped' >> /var/tmp/container_base_images_log.txt");
    } else {
        install_docker_when_needed();
        foreach my $image (@images) {
            test_container_image($image, 'latest', 'docker');
            script_run("echo 'OK: docker - $image:latest' >> /var/tmp/container_base_images_log.txt");
        }
        foreach my $image (@docker_images) {
            test_container_image($image, 'latest', 'docker');
            script_run("echo 'OK: docker - $image:latest' >> /var/tmp/container_base_images_log.txt");
        }
        clean_docker_host();
    }
    # Run podman tests
    if (is_sle || check_var("SKIP_PODMAN_IMAGE_TESTS", 1)) {
        record_info("Skip Podman", "Podman image tests skipped");
        script_run("echo 'INFO: Podman image tests skipped' >> /var/tmp/container_base_images_log.txt");
    } else {
        zypper_call('in podman', timeout => 900);
        foreach my $image (@images) {
            test_container_image($image, 'latest', 'podman');
            script_run("echo 'OK: podman - $image:latest' >> /var/tmp/container_base_images_log.txt");
        }
        foreach my $image (@podman_images) {
            test_container_image($image, 'latest', 'podman');
            script_run("echo 'OK: podman - $image:latest' >> /var/tmp/container_base_images_log.txt");
        }
    }
}

sub cleanup {
    # Rename for better visibility in Uploaded Logs
    if (script_run('mv /var/tmp/container_base_images_log.txt logs.txt') != 0) {
        record_info("No logs", "No logs found");
    } else {
        upload_logs("logs.txt");
        script_run("rm logs.txt");
    }
}

sub post_fail_hook {
    cleanup();
}

sub post_run_hook {
    cleanup();
}


1;
