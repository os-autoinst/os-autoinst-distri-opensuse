# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: docker
# Summary: Test installation and running of the docker image from the registry for this snapshot.
# This module is unified to run independented the host os.
# - if on SLE, enable internal registry
# - load image
# - run container
# - run some zypper commands with zypper-decker if is sle/opensuse
# - try to run a single cat command if not sle/opensuse
# - commit the image
# - remove the container, run it again and verify that the new image works
# Maintainer: Pavel Dostál <pdostal@suse.cz>, qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_suse_container_urls';
use version_utils qw(get_os_release check_os_release);

sub run {
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    my $docker = containers::runtime->new(engine => 'docker');

    install_docker_when_needed($host_distri);
    allow_selected_insecure_registries($docker);
    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));

    for my $iname (@{$image_names}) {
        test_container_image($docker, image => $iname);
        build_container_image($docker, $iname);
        if (check_os_release('suse', 'PRETTY_NAME')) {
            test_opensuse_based_image($docker, image => $iname);
            build_with_zypper_docker($docker, image => $iname);
        }
        else {
            $docker->exec_on_container($iname, 'cat /etc/os-release');
        }
    }
    scc_restore_docker_image_credentials();
    $docker->cleanup_system_host();
}

1;
