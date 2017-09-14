# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test docker installation and extended usage
#    Cover the following aspects of docker:
#      * package can be installed
#      * daemon can be started
#      * images can be searched on the Docker Hub
#      * images can be pulled from the Docker Hub
#      * containers can be spawned, started on background, stopped, deleted
#      * images can be deleted
#      * network is working inside of the containers
# Maintainer: Petr Cervinka <pcervinka@suse.com>, Flavio Castelli <fcastelli@suse.com>


use base "consoletest";
use testapi;
use utils;
use strict;

sub run {
    select_console("root-console");

    if (is_caasp && check_var('FLAVOR', 'DVD') && !check_var('SYSTEM_ROLE', 'plain')) {
        # Docker should be pre-installed in MicroOS
        die "Docker is not pre-installed." if script_run("rpm -q docker");
    }
    else {
        zypper_call("in docker");
    }

    # start the docker daemon
    systemctl("start docker");

    # check status of docker daemon
    systemctl("status docker");

    # do search for openSUSE
    validate_script_output("docker search  --no-trunc opensuse", sub { m/This project contains the stable releases of the openSUSE distribution/ });

    # pull minimalistic alpine image
    # https://store.docker.com/images/alpine
    assert_script_run("docker pull alpine", 300);

    # Check if the alpine image has been fetched
    assert_script_run("docker images -q alpine:latest");

    # pull hello-world image, typical docker demo image
    # https://store.docker.com/images/hello-world
    assert_script_run("docker pull hello-world", 300);

    # Check if the hello-world image has been fetched
    assert_script_run("docker images -q hello-world:latest");

    # run hello-world container and name it test_1
    validate_script_output("docker run --name test_1 hello-world", sub { m/Hello from Docker/ });

    # run hello world from alpine and name it test_2
    validate_script_output("docker run --name test_2 alpine /bin/echo Hello world", sub { m/Hello world/ });

    # Check that we have 2 containers with the proper naming scheme
    validate_script_output("docker ps -a", sub { m/test_1/ });
    validate_script_output("docker ps -a", sub { m/test_2/ });

    # run hello world from alpine as an ephemeral container
    validate_script_output("docker run --name test_ephemeral --rm alpine /bin/echo Hello world", sub { m/Hello world/ });

    # list docker images
    validate_script_output("docker images", sub { m/alpine/ });

    # run alpine container on background and get back its id
    my ($container_id) = script_output("docker run -d -t -i alpine /bin/sh") =~ /(.+)/;

    # check that alpine container is running (in background)
    script_run("docker inspect --format='{{.State.Running}}' ${container_id}");
    validate_script_output("docker inspect --format='{{.State.Running}}' ${container_id}", sub { m/true/ });

    # stop running container
    assert_script_run("docker stop ${container_id}");

    # check that alpine container should not be running anymore
    validate_script_output("docker inspect --format='{{.State.Running}}' ${container_id}", sub { m/false/ });

    # network test
    script_run("docker run --rm alpine wget http://google.com && echo 'container_network_works' > /dev/$serialdev", 0);
    die("network does not work inside of the container") unless wait_serial("container_network_works", 200);

    # remove all containers related to alpine and hello-world
    assert_script_run("docker rm \$(docker ps -a | grep 'alpine\\|hello-world' | awk '{print \$1}')");

    # Remove the alpine and hello-world images
    assert_script_run("docker images | grep 'alpine\\|hello-world' | awk '{print \$1}' | xargs docker rmi");

}

1;
# vim: set sw=4 et:
