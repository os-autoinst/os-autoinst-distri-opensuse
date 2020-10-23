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
use version_utils qw(get_os_release check_host_os);

sub run {
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $runtime = "podman";
    install_podman_when_needed($host_distri);
    allow_selected_insecure_registries(runtime => $runtime);
    for my $iname (@{$image_names}) {
        test_container_image(image => $iname, runtime => $runtime);
        build_container_image(image => $iname, runtime => $runtime);
        if (check_host_os('suse')) {
            test_opensuse_based_image(image => $iname, runtime => $runtime);
        }
        else {
            exec_on_container($iname, $runtime, 'cat /etc/os-release');
        }
    }
    clean_container_host(runtime => $runtime);
}

1;
