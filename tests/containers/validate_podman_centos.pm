# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test podman running on Centos host
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use containers::container_images;
use suse_container_urls 'get_suse_container_urls';

sub run {
    my ($image_names, $stable_names) = get_suse_container_urls();
    my $container_mgmt_tool = "podman";
    install_podman_centos();
    allow_selected_insecure_registries(runtime => $container_mgmt_tool);
    for my $i (0 .. $#$image_names) {
        test_container_image(image => $image_names->[$i], runtime => $container_mgmt_tool);
        build_container_image(image => $image_names->[$i], runtime => $container_mgmt_tool);
        exec_cmd($image_names->[$i], $container_mgmt_tool, 'cat /etc/os-release');
    }
    clean_container_host(runtime => $container_mgmt_tool);
}

1;
