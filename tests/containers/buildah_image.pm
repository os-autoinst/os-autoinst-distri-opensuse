# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: buildah
# Summary: building OCI-compatible sle base images with buildah.
# - install buildah
# - create and run container
# - build image with service and test connectivity
# - cleanup system (images, containers)
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_suse_container_urls';
use version_utils qw(get_os_release check_os_release);
use version_utils 'is_sle';

sub run {
    my ($image_names, $stable_names) = get_suse_container_urls();
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_buildah_when_needed($host_distri);
    install_podman_when_needed($host_distri);
    install_docker_when_needed($host_distri);
    allow_selected_insecure_registries(runtime => 'docker');
    allow_selected_insecure_registries(runtime => 'podman');
    scc_apply_docker_image_credentials() if (get_var('SCC_DOCKER_IMAGE'));

    for my $iname (@{$image_names}) {
        test_container_image(image => $iname, runtime => 'buildah');
        if (check_os_release('suse', 'PRETTY_NAME')) {
            # sle15-working-container is the default name given to a container. it is created in test_container_image
            test_opensuse_based_image(image => 'sle15-working-container', runtime => 'buildah');
            # Due to the steps from the test_opensuse_based_image previously,
            # the image has been committed as refreshed
            test_containered_app(runtime => 'podman',
                buildah    => 1,
                dockerfile => 'Dockerfile.suse',
                base       => 'refreshed');
            assert_script_run "podman rmi -f myapp";
            test_containered_app(runtime => 'docker',
                buildah    => 1,
                dockerfile => 'Dockerfile.suse',
                base       => 'refreshed');
            if (is_sle) {
                my $container_id = script_output "docker ps -aqf 'ancestor=myapp'";
                assert_script_run "docker cp /etc/SUSEConnect $container_id:/etc/SUSEConnect";
                assert_script_run "docker cp /etc/zypp/credentials.d/SCCcredentials $container_id:/etc/zypp/credentials.d/SCCcredentials";
                assert_script_run "docker exec -it $container_id zypper lr";
            }
        }
    }
    scc_restore_docker_image_credentials();
    clean_container_host(runtime => 'podman');
    clean_container_host(runtime => 'docker');
    clean_container_host(runtime => 'buildah');
}

1;
