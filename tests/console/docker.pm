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
#      * containers state can be saved to an image
#      * network is working inside of the containers
#      * containers can be stopped
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
    #   - pull image of last released version of openSUSE Leap
    my $last_released_leap_version = '42.3';
    assert_script_run("docker image pull opensuse:$last_released_leap_version", timeout => 180);
    #   - pull image of openSUSE Tumbleweed
    assert_script_run('docker image pull opensuse:tumbleweed', timeout => 180);

    # local images can be listed
    #   - BUG https://github.com/docker/for-linux/issues/220
    assert_script_run('docker image ls none');
    record_soft_failure('https://github.com/docker/for-linux/issues/220');
    #   - filter with tag
    assert_script_run(qq{docker image ls alpine:$alpine_image_version | grep "alpine\\s*$alpine_image_version"});
    #   - filter without tag
    assert_script_run(qq{docker image ls hello-world | grep "hello-world\\s*latest"});
    #   - all local images
    my $local_images_list = script_output('docker image ls');
    die('docker image opensuse:tumbleweed not found')                  unless ($local_images_list =~ /opensuse\s*tumbleweed/);
    die("docker image opensuse:$last_released_leap_version not found") unless ($local_images_list =~ /opensuse\s*\Q$last_released_leap_version\E/);

    # containers can be spawned
    #   - using 'run'
    assert_script_run('docker container run --name test_1 hello-world | grep "Hello from Docker\!"');
    #   - using 'create', 'start' and 'logs' (background container)
    assert_script_run("docker container create --name test_2 alpine:$alpine_image_version /bin/echo Hello world");
    assert_script_run('docker container start test_2 | grep "test_2"');
    assert_script_run('docker container logs test_2 | grep "Hello world"');
    #   - using 'run --rm'
    assert_script_run(qq{docker container run --name test_ephemeral --rm alpine:$alpine_image_version /bin/echo Hello world | grep "Hello world"});
    #   - using 'run -d' and 'inspect' (background container)
    my $container_name = 'tw';
    assert_script_run("docker container run -d --name $container_name opensuse:tumbleweed tail -f /dev/null");
    assert_script_run("docker container inspect --format='{{.State.Running}}' $container_name | grep true");
    my $output_containers = script_output('docker container ls -a');
    die('error: missing container test_1') unless ($output_containers =~ m/test_1/);
    die('error: missing container test_2') unless ($output_containers =~ m/test_2/);
    die('error: ephemeral container was not removed') if ($output_containers =~ m/test_ephemeral/);
    die("error: missing container $container_name") unless ($output_containers =~ m/$container_name/);

    # containers state can be saved to a docker image
    my $output = script_output("docker container exec $container_name zypper -n in curl");
    die('error: curl not installed in the container') unless ($output =~ m/Installing: curl.*done/);
    assert_script_run("docker container commit $container_name tw:saved");

    # network is working inside of the containers
    $output = script_output('docker container run tw:saved curl -I google.de');
    die("network is not working inside of the container tw:saved") unless ($output =~ m{Location: http://www\.google\.de/});

    # containers can be stopped
    assert_script_run("docker container stop $container_name");
    assert_script_run("docker container inspect --format='{{.State.Running}}' $container_name | grep false");

    # containers can be deleted
    my $cmd_docker_rm = 'docker container rm test_1';
    assert_script_run("$cmd_docker_rm | grep test_1");
    $output_containers = script_output('docker container ls -a');
    die("error: container was not removed: $cmd_docker_rm") if ($output_containers =~ m/test_1/);
    my $cmd_docker_container_prune = 'docker container prune -f';
    assert_script_run("$cmd_docker_container_prune");
    $output_containers = script_output('docker container ls -a');
    die("error: container was not removed: $cmd_docker_container_prune") if ($output_containers =~ m/test_2/);

    # images can be deleted
    #  - using filter
    my $output_deleted = script_output("docker image rm alpine:$alpine_image_version hello-world");
    die('error: could not remove image: hello-world:latest')                              unless ($output_deleted =~ m/Untagged: hello-world:latest/);
    die("error: could not remove image: hello-world:latest alpine:$alpine_image_version") unless ($output_deleted =~ m/Untagged: alpine:$alpine_image_version/);
    #  - clean up images
    assert_script_run('docker image rm $(docker image ls -q)');
    assert_script_run('docker image ls | wc -l | grep -E "\s1$');
}

1;
# vim: set sw=4 et:
