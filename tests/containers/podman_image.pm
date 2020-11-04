# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: podman
# Summary: Test installation and running of the docker image from the registry for this snapshot
# This module is unified to run independented the host os.
# Maintainer: Fabian Vogt <fvogt@suse.com>, qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use containers::container_images;
use suse_container_urls 'get_suse_container_urls';
use version_utils qw(get_os_release check_os_release);
use containers::utils 'can_build_sle_base';

sub run {
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $container_engine  = "podman";
    my $is_build_possible = can_build_sle_base($image_names);
    install_podman_when_needed($host_distri, $is_build_possible);
    allow_selected_insecure_registries(runtime => $container_engine);
    for my $iname (@{$image_names}) {
        test_container_image(image => $iname, runtime => $container_engine);
        build_container_image(image => $iname, runtime => $container_engine) if can_build_sle_base($iname);
        if (check_os_release('suse', 'PRETTY_NAME')) {
            test_suse_based_image(image => $iname, runtime => $container_engine);
        }
        else {
            exec_on_container($iname, $container_engine, 'cat /etc/os-release');
        }
    }
    clean_container_host(runtime => $container_engine);
}

1;
