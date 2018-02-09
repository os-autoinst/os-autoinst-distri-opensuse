# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test docker installation and extended usage
#    Cover the following aspects of docker:
#      * docker package can be installed
#      * docker daemon can be started
#      * images can be searched on the Docker Hub
#      * images can be pulled from the Docker Hub
#      * local images can be listed
#      * containers can be spawned
#      * containers can be run on background
#      * containers can be stopped
#      * network is working inside of the containers
#      * containers can be deleted
#      * images can be deleted
# Maintainer: Petr Cervinka <pcervinka@suse.com>, Flavio Castelli <fcastelli@suse.com>

use base "consoletest";
use testapi;
use utils;
use strict;
use version_utils 'is_caasp';

sub run {
    select_console("root-console");

    if (is_caasp) {
        # Docker should be pre-installed in MicroOS
        die "Docker is not pre-installed." if script_run("zypper se -x --provides -i docker | grep docker");
    }
    else {
        # docker package can be installed
        zypper_call("in docker");
    }

    # docker daemon can be started
    systemctl("start docker");
    systemctl("status docker");
    assert_script_run('docker info');

    # images can be searched on the Docker Hub
    validate_script_output("docker search --no-trunc opensuse", sub { m/This project contains the stable releases of the openSUSE distribution/ });

    # images can be pulled from the Docker Hub
    #   - pull minimalistic alpine image of declared version
    #   - https://store.docker.com/images/alpine
    my $alpine_image_version = '3.5';
    assert_script_run("docker pull alpine:$alpine_image_version", 300);
    assert_script_run("docker images -q alpine:$alpine_image_version");
    #   - pull hello-world image, typical docker demo image
    #   - https://store.docker.com/images/hello-world
    assert_script_run("docker pull hello-world", 300);
    assert_script_run("docker images -q hello-world:latest");

    # local images can be listed
    validate_script_output("docker images", sub { m/alpine/ });

    # containers can be spawned
    validate_script_output("docker run --name test_1 hello-world",                                                     sub { m/Hello from Docker/ });
    validate_script_output("docker run --name test_2 alpine:$alpine_image_version /bin/echo Hello world",              sub { m/Hello world/ });
    validate_script_output("docker ps -a",                                                                             sub { m/test_1/ });
    validate_script_output("docker ps -a",                                                                             sub { m/test_2/ });
    validate_script_output("docker run --name test_ephemeral --rm alpine:$alpine_image_version /bin/echo Hello world", sub { m/Hello world/ });

    # containers can be run on background
    my ($container_id) = script_output("docker run -d -t -i alpine:$alpine_image_version /bin/sh") =~ /(.+)/;
    script_run("docker inspect --format='{{.State.Running}}' ${container_id}");
    validate_script_output("docker inspect --format='{{.State.Running}}' ${container_id}", sub { m/true/ });

    # containers can be stopped
    assert_script_run("docker stop ${container_id}");

    # check that alpine container should not be running anymore
    validate_script_output("docker inspect --format='{{.State.Running}}' ${container_id}", sub { m/false/ });

    # network is working inside of the containers
    script_run("docker run --rm alpine:$alpine_image_version wget http://google.com && echo 'container_network_works' > /dev/$serialdev", 0);
    die("network does not work inside of the container") unless wait_serial("container_network_works", 200);

    # containers can be deleted
    assert_script_run("docker rm \$(docker ps -a | grep 'alpine\\|hello-world' | awk '{print \$1}')");

    # images can be deleted
    assert_script_run("docker images | grep 'alpine\\|hello-world' | awk '{print \$3}' | xargs docker rmi");

}

1;
# vim: set sw=4 et:
