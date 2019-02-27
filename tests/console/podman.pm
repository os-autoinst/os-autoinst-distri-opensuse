# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test podman installation and extended usage in a Kubic system
#    Cover the following aspects of podman:
#      * podman daemon can be started
#      * images can be searched on the default registry
#      * images can be pulled from the default registry
#      * local images can be listed
#      * containers can be spawned
#      * containers state can be saved to an image
#      * network is working inside of the containers
#      * containers can be stopped
#      * containers can be deleted
#      * images can be deleted
# Maintainer: Richard Brown <rbrown@suse.com>

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use registration;
use version_utils qw(is_sle is_leap);

sub run {
    select_console("root-console");

    # images can be searched on the default registry
    validate_script_output("podman search --no-trunc tumbleweed", sub { m/Official openSUSE Tumbleweed images/ });

    # images can be pulled from the default registry
    #   - pull minimalistic alpine image of declared version using tag
    #   - https://store.docker.com/images/alpine
    my $alpine_image_version = '3.6';
    assert_script_run("podman image pull alpine:$alpine_image_version", timeout => 300);
    #   - pull typical podman demo image without tag. Should be latest.
    #   - https://store.docker.com/images/hello-world
    assert_script_run("podman image pull hello-world", timeout => 300);
    #   - pull image of last released version of openSUSE Leap
    assert_script_run("podman image pull opensuse/leap", timeout => 600);
    #   - pull image of openSUSE Tumbleweed
    assert_script_run('podman image pull opensuse/tumbleweed', timeout => 600);

    # local images can be listed
    assert_script_run('podman image ls');
    #   - filter with tag
    assert_script_run(qq{podman image ls alpine:$alpine_image_version | grep "alpine\\s*$alpine_image_version"});
    #   - filter without tag
    assert_script_run(qq{podman image ls hello-world | grep "hello-world\\s*latest"});
    #   - all local images
    my $local_images_list = script_output('podman image ls');
    die('podman image opensuse/tumbleweed not found') unless ($local_images_list =~ /opensuse\/tumbleweed\s*latest/);
    die("podman image opensuse/leap not found")       unless ($local_images_list =~ /opensuse\/leap\s*latest/);

    # containers can be spawned
    #   - using 'run'
    assert_script_run('podman container run --name test_1 hello-world | grep "Hello from Docker\!"');
    #   - using 'create', 'start' and 'logs' (background container)
    assert_script_run("podman container create --name test_2 alpine:$alpine_image_version /bin/echo Hello world");
    assert_script_run('podman container start test_2 | grep "test_2"');
    assert_script_run('podman container logs test_2 | grep "Hello world"');
    #   - using 'run --rm'
    assert_script_run(qq{podman container run --name test_ephemeral --rm alpine:$alpine_image_version /bin/echo Hello world | grep "Hello world"});
    #   - using 'run -d' and 'inspect' (background container)
    my $container_name = 'tw';
    assert_script_run("podman container run -d --name $container_name opensuse/tumbleweed tail -f /dev/null");
    assert_script_run("podman container inspect --format='{{.State.Running}}' $container_name | grep true");
    my $output_containers = script_output('podman container ls -a');
    die('error: missing container test_1') unless ($output_containers =~ m/test_1/);
    die('error: missing container test_2') unless ($output_containers =~ m/test_2/);
    die('error: ephemeral container was not removed') if ($output_containers =~ m/test_ephemeral/);
    die("error: missing container $container_name") unless ($output_containers =~ m/$container_name/);

    # containers state can be saved to a podman image
    my $exit_code = script_run("podman container exec $container_name zypper -n in curl", 300);
    if ($exit_code) {
        record_info('poo#40958 - curl install failure, try with force-resolution.');
        my $output = script_output("podman container exec $container_name zypper in --force-resolution -y -n curl", 300);
        die('error: curl not installed in the container') unless ($output =~ m/Installing: curl.*done/);
    }
    assert_script_run("podman container commit $container_name tw:saved");

    # network is working inside of the containers
    my $output = script_output('podman container run tw:saved curl -I google.de');
    die("network is not working inside of the container tw:saved") unless ($output =~ m{Location: http://www\.google\.de/});

    # Using an init process as PID 1
    assert_script_run 'podman run --rm --init opensuse/tumbleweed ps --no-headers -xo "pid args" | grep "1 /dev/init"';

    if (script_run('command -v man') == 0) {
        assert_script_run('man -P cat podman build | grep "podman-build - Build a container image using a Dockerfile"');
    }

    # containers can be stopped
    assert_script_run("podman container stop $container_name");
    assert_script_run("podman container inspect --format='{{.State.Running}}' $container_name | grep false");

    # containers can be deleted
    my $cmd_podman_rm = 'podman container rm test_1';
    assert_script_run("$cmd_podman_rm");
    $output_containers = script_output('podman container ls -a');
    die("error: container was not removed: $cmd_podman_rm") if ($output_containers =~ m/test_1/);
    my $cmd_podman_container_prune = 'podman container prune';
    assert_script_run("$cmd_podman_container_prune");
    $output_containers = script_output('podman container ls -a');
    die("error: container was not removed: $cmd_podman_container_prune") if ($output_containers =~ m/test_2/);

    # images can be deleted
    my $cmd_podman_rmi = "podman rmi -a";
    $output_containers = script_output('podman container ls -a');
    die('error: podman rmi -a did not remove opensuse/leap')                if ($output_containers =~ m/Untagged: opensuse\/leap/);
    die('error: podman rmi -a did not remove opensuse/tumbleweed')          if ($output_containers =~ m/Untagged: opensuse\/tumbleweed/);
    die('error: podman rmi -a did not remove tw:saved')                     if ($output_containers =~ m/Untagged: tw:saved/);
    die("error: podman rmi -a did not remove alpine:$alpine_image_version") if ($output_containers =~ m/Untagged: alpine:$alpine_image_version/);
    die('error: podman rmi -a did not remove hello-world:latest')           if ($output_containers =~ m/Untagged: hello-world:latest/);
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    script_run "podman version | tee /dev/$serialdev";
    script_run "podman info --debug | tee /dev/$serialdev";
    $self->SUPER::post_fail_hook;
}

1;
