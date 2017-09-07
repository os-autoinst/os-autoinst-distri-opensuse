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

    if (check_var("DISTRI", "caasp")) {
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

    # get docker infor after installation and check number of images, should be 0
    validate_script_output("docker info", sub { m/Images\: 0/ });

    # do search for openSUSE
    validate_script_output("docker search  --no-trunc opensuse", sub { m/This project contains the stable releases of the openSUSE distribution/ });

    # pull minimalistic alpine image
    # https://store.docker.com/images/alpine
    assert_script_run("docker pull alpine", 300);

    # check number of images, should be 1
    validate_script_output("docker info", sub { m/Images\: 1/ });

    # pull hello-world image, typical docker demo image
    # https://store.docker.com/images/hello-world
    assert_script_run("docker pull hello-world", 300);

    # check number of images, should be 2
    validate_script_output("docker info", sub { m/Images\: 2/ });

    # run hello-world
    validate_script_output("docker run hello-world", sub { m/Hello from Docker/ });

    # run hello world from alpine
    validate_script_output("docker run alpine /bin/echo Hello world", sub { m/Hello world/ });

    # check number of containers, should be 2
    validate_script_output("docker info", sub { m/Containers\: 2/ });

    # run hello world from alpine and delete container
    validate_script_output("docker run --rm alpine /bin/echo Hello world", sub { m/Hello world/ });

    # check number of containers, still should be 2
    validate_script_output("docker info", sub { m/Containers\: 2/ });

    # list docker images
    validate_script_output("docker images", sub { m/alpine/ });

    # run alpine container on background and get back its id
    my ($container_id) = script_output("docker run -d -t -i alpine /bin/sh") =~ /(.+)/;

    # check number of running containers, should be 1
    validate_script_output("docker info", sub { m/Running\: 1/ });

    # check number of running containers, should be 1
    validate_script_output("docker ps --no-trunc -q", sub { m/${container_id}/ });

    # stop running container
    assert_script_run("docker stop ${container_id}");

    # check number of running containers, should be 0
    validate_script_output("docker info", sub { m/Running\: 0/ });

    # network test
    script_run("docker run --rm alpine wget http://google.com && echo 'container_network_works' > /dev/$serialdev", 0);
    die("network does not work inside of the container") unless wait_serial("container_network_works", 200);

    # remove all containers
    assert_script_run("docker rm \$(docker ps -a -q)");

    # check number of containers, should be 0
    validate_script_output("docker info", sub { m/Containers\: 0/ });

    # remove all images
    assert_script_run("docker rmi --force \$(docker images -a -q)");

    # check number of images, should be 0
    validate_script_output("docker info", sub { m/Images\: 0/ });
}

1;
# vim: set sw=4 et:
