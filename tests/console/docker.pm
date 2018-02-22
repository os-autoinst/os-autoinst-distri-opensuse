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
# Maintainer: Flavio Castelli <fcastelli@suse.com>, Panagiotis Georgiadis <pgeorgiadis@suse.com>, Sergio Lindo Mansilla <slindomansilla@suse.com>

use base "consoletest";
use testapi;
use utils;
use strict;
use version_utils qw(is_caasp is_sle sle_version_at_least);
use registration;

sub run {
    select_console("root-console");

    if (is_caasp) {
        # Docker should be pre-installed in MicroOS
        die "Docker is not pre-installed." if script_run("zypper se -x --provides -i docker | grep docker");
    }
    else {
        add_suseconnect_product('sle-module-containers') if is_sle && sle_version_at_least('15');
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
    #   - pull minimalistic alpine image of declared version using tag
    #   - https://store.docker.com/images/alpine
    my $alpine_image_version = '3.5';
    assert_script_run("docker image pull alpine:$alpine_image_version", 300);
    #   - pull typical docker demo image without tag. Should be latest.
    #   - https://store.docker.com/images/hello-world
    assert_script_run("docker image pull hello-world", 300);

    # local images can be listed
    # BUG https://github.com/docker/for-linux/issues/220
    assert_script_run('docker images none');
    record_soft_failure('https://github.com/docker/for-linux/issues/220');
    assert_script_run("docker images alpine:$alpine_image_version | grep alpine");
    assert_script_run("docker images hello-world | grep latest");

    # containers can be spawned
    assert_script_run('docker container run --name test_1 hello-world | grep "Hello from Docker\!"');
    assert_script_run(qq{docker container run --name test_2 alpine:$alpine_image_version /bin/echo Hello world | grep "Hello world"});
    assert_script_run(qq{docker container run --name test_ephemeral --rm alpine:$alpine_image_version /bin/echo Hello world | grep "Hello world"});
    my $cmd_docker_container_ls = 'docker container ls -a';
    my $output_containers       = script_output($cmd_docker_container_ls);
    die('error: missing container test_1') unless ($output_containers =~ m/test_1/);
    die('error: missing container test_2') unless ($output_containers =~ m/test_2/);
    die('error: ephemeral container was not removed') if ($output_containers =~ m/test_ephemeral/);

    # containers can be run on background
    my ($container_id) = script_output("docker container run -d alpine:$alpine_image_version tail -f /dev/null") =~ /(.+)/;
    assert_script_run("docker container inspect --format='{{.State.Running}}' ${container_id} | grep true");

    # containers can be stopped
    assert_script_run("docker container stop ${container_id}");
    assert_script_run("docker container inspect --format='{{.State.Running}}' ${container_id} | grep false");

    # network is working inside of the containers
    assert_script_run(qq{docker container run --rm alpine:$alpine_image_version wget http://google.com 2>&1 | grep "index.html\\s*100%"});

    # containers can be deleted
    my $cmd_docker_rm = 'docker container rm test_1';
    assert_script_run("$cmd_docker_rm | grep test_1");
    $output_containers = script_output($cmd_docker_container_ls);
    die("error: container was not removed: $cmd_docker_rm") if ($output_containers =~ m/test_1/);
    my $cmd_docker_container_prune = 'docker container prune -f';
    assert_script_run("$cmd_docker_container_prune");
    $output_containers = script_output($cmd_docker_container_ls);
    die("error: container was not removed: $cmd_docker_container_prune") if ($output_containers =~ m/test_2/);

    # images can be deleted
    my $cmd_docker_rmi = "docker image rm alpine:$alpine_image_version hello-world";
    my $output_deleted = script_output($cmd_docker_rmi);
    unless ($output_deleted =~ m/Untagged: hello-world:latest/ && $output_deleted =~ m/Untagged: alpine:$alpine_image_version/) {
        die("error: could not remove images: $cmd_docker_rmi");
    }
}

1;
# vim: set sw=4 et:
