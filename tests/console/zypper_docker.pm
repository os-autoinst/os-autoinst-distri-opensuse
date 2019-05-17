# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test zypper-docker installation and its usage
#    Cover the following aspects of zypper-docker:
#      * zypper-docker package can be installed
#      * zypper-docker can list local images:                    'zypper-docker images ls'
#      * zypper-docker can list updates/patches:                 'zypper-docker list-updates' 'zypper-docker list-patches'
#      * zypper-docker can list outdated containers:             'zypper-docker ps'
#      * zypper-docker can list updates/patches for a container: 'zypper-docker list-updates-container' 'zypper-docker list-patches-container'
#      * zypper-docker can apply the updates:                    'zypper-docker update'
# Maintainer: Antonio Caristia <acaristia@suse.com>

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use registration;
use version_utils 'is_sle';

sub run {
    select_console("root-console");

    install_docker_when_needed();

    # install zypper-docker and verify installation
    zypper_call('in zypper-docker');
    validate_script_output("zypper-docker -h", sub { m/zypper-docker - Patching Docker images safely/ }, 180);

    my $testing_image = 'opensuse/leap';
    # pull image and check zypper-docker's images funcionalities
    assert_script_run("docker image pull $testing_image", timeout => 600);
    my $local_images_list = script_output('docker images');
    die("docker image $testing_image not found") unless ($local_images_list =~ /opensuse\s*/);
    validate_script_output("zypper-docker images ls", sub { m/opensuse/ }, 180);
    assert_script_run("zypper-docker list-updates $testing_image", timeout => 600);
    assert_script_run("zypper-docker list-patches $testing_image", timeout => 600);
    # run a container and check zypper-docker's containers funcionalities
    assert_script_run("docker container run -d --name tmp_container $testing_image tail -f /dev/null");
    assert_script_run("zypper-docker ps",                                   timeout => 600);
    assert_script_run("zypper-docker list-updates-container tmp_container", timeout => 600);
    assert_script_run("zypper-docker list-patches-container tmp_container", timeout => 600);
    # apply all the updates to a new_image
    if (is_sle('>=15')) {
        record_soft_failure 'bsc#1123173';
    } else {
        assert_script_run("zypper-docker update --auto-agree-with-licenses $testing_image new_image", timeout => 600);
    }
}

1;
