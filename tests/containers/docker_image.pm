# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation and running of the docker image from the registry for this snapshot
# - if on SLE, enable internal registry
# - load image
# - run container
# - run some zypper commands
# - commit the image
# - remove the container, run it again and verify that the new image works
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base 'consoletest';
use testapi;
use utils;
use strict;
use warnings;
use containers::common;
use containers::container_images;
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap is_public_cloud);

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my ($image_names, $stable_names) = get_suse_container_urls();

    install_docker_when_needed();

    if (is_sle()) {
        ensure_ca_certificates_suse_installed();
        allow_registry_suse_de_for_docker();
    }

    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));

    for my $i (0 .. $#$image_names) {
        test_container_image(image => $image_names->[$i], runtime => 'docker');
        build_container_image(image => $image_names->[$i], runtime => 'docker');
        test_opensuse_based_image(image => $image_names->[$i], runtime => 'docker');
    }

    scc_restore_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));
    clean_container_host(runtime => 'docker');
}

1;
