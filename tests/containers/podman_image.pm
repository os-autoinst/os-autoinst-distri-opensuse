# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation and running of the docker image from the registry for this snapshot
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base 'consoletest';
use testapi;
use utils;
use strict;
use warnings;
use containers::common;
use containers::container_images;
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my ($image_names, $stable_names) = get_suse_container_urls();

    ensure_ca_certificates_suse_installed() if (is_sle());
    install_podman_when_needed();

    for my $i (0 .. $#$image_names) {
        test_container_image(image => $image_names->[$i], runtime => 'podman');
        build_container_image(image => $image_names->[$i], runtime => 'podman');
        test_opensuse_based_image(image => $image_names->[$i], runtime => 'podman');
    }
    clean_container_host(runtime => 'podman');
}

1;
