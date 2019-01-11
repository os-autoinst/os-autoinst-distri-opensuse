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
use registration;
use version_utils qw(is_sle is_leap);

sub test_seccomp {
    my $no_seccomp = script_run('docker info | tee /dev/tty | grep seccomp');
    if ($no_seccomp) {
        my $err_seccomp_support = 'boo#1072367 - Docker Engine does NOT have seccomp support';
        if (is_sle('<15') || is_leap('<15.0')) {
            record_info('WONTFIX', $err_seccomp_support);
        }
        else {
            die($err_seccomp_support);
        }
    }
    else {
        record_info('seccomp', 'Docker Engine supports seccomp');
    }
}

sub run {
    select_console("root-console");

    install_docker_when_needed();
    test_seccomp();

    # images can be searched on the Docker Hub
    validate_script_output("docker search --no-trunc opensuse", sub { m/This project contains the stable releases of the openSUSE distribution/ });

    # images can be pulled from the Docker Hub
    #   - pull minimalistic alpine image of declared version using tag
    #   - https://store.docker.com/images/alpine
    my $alpine_image_version = '3.6';
    assert_script_run("docker image pull alpine:$alpine_image_version", timeout => 300);
    #   - pull typical docker demo image without tag. Should be latest.
    #   - https://store.docker.com/images/hello-world
    assert_script_run("docker image pull hello-world", timeout => 300);
    #   - pull image of last released version of openSUSE Leap
    assert_script_run("docker image pull opensuse/leap", timeout => 600);
    #   - pull image of openSUSE Tumbleweed
    assert_script_run('docker image pull opensuse/tumbleweed', timeout => 600);

    # local images can be listed
    assert_script_run('docker image ls none');
    #   - filter with tag
    assert_script_run(qq{docker image ls alpine:$alpine_image_version | grep "alpine\\s*$alpine_image_version"});
    #   - filter without tag
    assert_script_run(qq{docker image ls hello-world | grep "hello-world\\s*latest"});
    #   - all local images
    my $local_images_list = script_output('docker image ls');
    die('docker image opensuse/tumbleweed not found') unless ($local_images_list =~ /opensuse\/tumbleweed\s*latest/);
    die("docker image opensuse/leap not found")       unless ($local_images_list =~ /opensuse\/leap\s*latest/);

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
    assert_script_run("docker container run -d --name $container_name opensuse/tumbleweed tail -f /dev/null");
    assert_script_run("docker container inspect --format='{{.State.Running}}' $container_name | grep true");
    my $output_containers = script_output('docker container ls -a');
    die('error: missing container test_1') unless ($output_containers =~ m/test_1/);
    die('error: missing container test_2') unless ($output_containers =~ m/test_2/);
    die('error: ephemeral container was not removed') if ($output_containers =~ m/test_ephemeral/);
    die("error: missing container $container_name") unless ($output_containers =~ m/$container_name/);

    # containers state can be saved to a docker image
    my $exit_code = script_run("docker container exec $container_name zypper -n in curl", 300);
    if ($exit_code) {
        record_info('poo#40958 - curl install failure, try with force-resolution.');
        my $output = script_output("docker container exec $container_name zypper in --force-resolution -y -n curl", 300);
        die('error: curl not installed in the container') unless ($output =~ m/Installing: curl.*done/);
    }
    assert_script_run("docker container commit $container_name tw:saved");

    # network is working inside of the containers
    my $output = script_output('docker container run tw:saved curl -I google.de');
    die("network is not working inside of the container tw:saved") unless ($output =~ m{Location: http://www\.google\.de/});

    # Using an init process as PID 1
    assert_script_run 'docker run --rm --init opensuse/tumbleweed ps --no-headers -xo "pid args" | grep "1 /dev/init"';

    if (script_run('command -v man') == 0) {
        assert_script_run('man -P cat docker build | grep "docker-build - Build an image from a Dockerfile"');
        assert_script_run('man -P cat docker config | grep "docker-config - Manage Docker configs"');
    }

    # Try to stop container using ctrl+c
    my $sleep_time = 30 * get_var('TIMEOUT_SCALE', 1);
    type_string("docker run --rm opensuse/tumbleweed sleep $sleep_time\n");
    type_string("# Let's press ctrl+c right now ... ");
    send_key 'ctrl-c';
    type_string("# ... and we seem to be still in container\n");
    # If echo works then ctrl-c stopped sleep
    type_string "echo 'ctrlc_timeout' > /dev/$serialdev\n";
    if (wait_serial('ctrlc_timeout', 10, 1) =~ 'ctrlc_timeout') {
        die 'ctrl-c stopped container';
    }
    die "Something went wrong" unless wait_serial('ctrlc_timeout', 40);

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
    my $cmd_docker_rmi = "docker image rm alpine:$alpine_image_version hello-world opensuse/leap opensuse/tumbleweed tw:saved";
    my $output_deleted = script_output($cmd_docker_rmi);
    die("error: docker image rm opensuse/leap")                unless ($output_deleted =~ m/Untagged: opensuse\/leap/);
    die('error: docker image rm opensuse/tumbleweed')          unless ($output_deleted =~ m/Untagged: opensuse\/tumbleweed/);
    die('error: docker image rm tw:saved')                     unless ($output_deleted =~ m/Untagged: tw:saved/);
    die("error: docker image rm alpine:$alpine_image_version") unless ($output_deleted =~ m/Untagged: alpine:$alpine_image_version/);
    die('error: docker image rm hello-world:latest')           unless ($output_deleted =~ m/Untagged: hello-world:latest/);
}

1;
