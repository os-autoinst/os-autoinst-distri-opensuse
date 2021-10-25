# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Pull and test various base images
#   (alpine, openSUSE, debian, ubuntu, fedora, centos, ubi)
#   for their base functionality
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use containers::common;
use registration;
use containers::engine;

our $runtime = undef;

sub get_3rd_party_images {
    my $ex_reg = get_var('REGISTRY', 'docker.io');
    my @images = (
        "registry.opensuse.org/opensuse/leap",
        "registry.opensuse.org/opensuse/tumbleweed",
        "$ex_reg/library/alpine",
        "$ex_reg/library/debian",
        "$ex_reg/library/fedora",
        "registry.access.redhat.com/ubi8/ubi",
        "registry.access.redhat.com/ubi8/ubi-minimal",
        "registry.access.redhat.com/ubi8/ubi-init");

    # poo#72124 Ubuntu image (occasionally) fails on s390x
    push @images, "$ex_reg/library/ubuntu" unless is_s390x;

    # Missing centos container image for s390x.
    push @images, "$ex_reg/library/centos" unless is_s390x;

    # RedHat UBI7 images are not built for aarch64
    push @images, (
        "registry.access.redhat.com/ubi7/ubi",
        "registry.access.redhat.com/ubi7/ubi-minimal",
        "registry.access.redhat.com/ubi7/ubi-init"
    ) unless (is_aarch64 or check_var('PUBLIC_CLOUD_ARCH', 'arm64'));

    return (\@images);
}


sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # CONTAINER_RUNTIME can be "docker", "podman" or "docker,podman"
    $runtime = containers::engine:->new(get_required_var('CONTAINER_RUNTIME');

    my $images = get_3rd_party_images();
    for my $image (@{$images}) {
        record_info('IMAGE', "Testing $image with $runtime");
        test_container_image(image => $image, runtime => $runtime);
    }
    $runtime->cleanup_system_host();
}

1;
