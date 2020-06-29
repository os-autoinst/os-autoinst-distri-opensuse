# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functions for testing docker
# Maintainer: Anna Minou <anna.minou@suse.de>, qa-c@suse.de

package containers::utils;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils;

our @EXPORT = qw(test_seccomp basic_container_tests set_up get_vars build_img test_built_img);

sub test_seccomp {
    my $no_seccomp = script_run('docker info | tee /dev/$serialdev | grep seccomp');
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

sub basic_container_tests {
    my $runtime = shift;
    die "You must define the runtime!" unless $runtime;

    # Search and pull images from the Docker Hub
    validate_script_output("$runtime search --no-trunc tumbleweed", sub { m/Official openSUSE Tumbleweed images/ });
    #   - pull minimalistic alpine image of declared version using tag
    #   - https://store.docker.com/images/alpine
    my $alpine_image_version = '3.6';
    assert_script_run("$runtime image pull alpine:$alpine_image_version", timeout => 300);
    #   - pull typical docker demo image without tag. Should be latest.
    #   - https://store.docker.com/images/hello-world
    assert_script_run("$runtime image pull hello-world", timeout => 300);
    #   - pull image of last released version of openSUSE Leap
    if (!check_var('ARCH', 's390x')) {
        assert_script_run("$runtime image pull opensuse/leap", timeout => 600);
    }
    else {
        record_soft_failure("bsc#1171672 Missing Leap:latest container image for s390x");
    }
    #   - pull image of openSUSE Tumbleweed
    assert_script_run("$runtime image pull opensuse/tumbleweed", timeout => 600);

    # Local images can be listed
    assert_script_run("$runtime image ls none");
    #   - filter with tag
    assert_script_run(qq{$runtime image ls alpine:$alpine_image_version | grep "alpine\\s*$alpine_image_version"});
    #   - filter without tag
    assert_script_run(qq{$runtime image ls hello-world | grep "hello-world\\s*latest"});
    #   - all local images
    my $local_images_list = script_output("$runtime image ls");
    die("$runtime image opensuse/tumbleweed not found") unless ($local_images_list =~ /opensuse\/tumbleweed\s*latest/);
    die("$runtime image opensuse/leap not found") if (!check_var('ARCH', 's390x') && !$local_images_list =~ /opensuse\/leap\s*latest/);

    # Containers can be spawned
    #   - using 'run'
    assert_script_run("$runtime container run --name test_1 hello-world | grep 'Hello from Docker\!'");
    #   - using 'create', 'start' and 'logs' (background container)
    assert_script_run("$runtime container create --name test_2 alpine:$alpine_image_version /bin/echo Hello world");
    assert_script_run("$runtime container start test_2 | grep test_2");
    assert_script_run("$runtime container logs test_2 | grep 'Hello world'");
    #   - using 'run --rm'
    assert_script_run(qq{$runtime container run --name test_ephemeral --rm alpine:$alpine_image_version /bin/echo Hello world | grep "Hello world"});
    #   - using 'run -d' and 'inspect' (background container)
    my $container_name = 'tw';
    assert_script_run("$runtime container run -d --name $container_name opensuse/tumbleweed tail -f /dev/null");
    assert_script_run("$runtime container inspect --format='{{.State.Running}}' $container_name | grep true");
    my $output_containers = script_output("$runtime container ls -a");
    die('error: missing container test_1') unless ($output_containers =~ m/test_1/);
    die('error: missing container test_2') unless ($output_containers =~ m/test_2/);
    die('error: ephemeral container was not removed') if ($output_containers =~ m/test_ephemeral/);
    die("error: missing container $container_name") unless ($output_containers =~ m/$container_name/);

    # Containers' state can be saved to a docker image
    my $exit_code = script_run("$runtime container exec $container_name zypper -n in curl", 300);
    if ($exit_code && !check_var('ARCH', 's390x')) {
        record_info('poo#40958 - curl install failure, try with force-resolution.');
        my $output = script_output("$runtime container exec $container_name zypper in --force-resolution -y -n curl", 600);
        die('error: curl not installed in the container') unless ($output =~ m/Installing: curl.*done/);
    }
    elsif (check_var('ARCH', 's390x')) {
        record_soft_failure("bsc#1165922 s390x control.xml has wrong repos");
    }
    assert_script_run("$runtime container commit $container_name tw:saved");

    # Network is working inside of the containers
    my $output = script_output("$runtime container run tw:saved curl -I google.de");
    die("network is not working inside of the container tw:saved") unless ($output =~ m{Location: http://www\.google\.de/});

    # Using an init process as PID 1
    assert_script_run "$runtime run --rm --init opensuse/tumbleweed ps --no-headers -xo 'pid args' | grep '1 .*init'";

    if (script_run('command -v man') == 0) {
        assert_script_run("man -P cat $runtime build | grep '$runtime-build - Build'");
    }

    # Containers can be stopped
    assert_script_run("$runtime container stop $container_name");
    assert_script_run("$runtime container inspect --format='{{.State.Running}}' $container_name | grep false");

    # Containers can be deleted
    my $cmd_docker_rm = "$runtime rm test_1";
    assert_script_run("$cmd_docker_rm");
    $output_containers = script_output("$runtime container ls -a");
    die("error: container was not removed: $cmd_docker_rm") if ($output_containers =~ m/test_1/);
    my $cmd_docker_container_prune = "$runtime container prune -f";
    assert_script_run("$cmd_docker_container_prune");
    $output_containers = script_output("$runtime container ls -a");
    die("error: container was not removed: $cmd_docker_container_prune") if ($output_containers =~ m/test_2/);

    # Images can be deleted
    my $cmd_runtime_rmi = "$runtime rmi -a";
    $output_containers = script_output("$runtime container ls -a");
    die("error: $runtime image rmi -a opensuse/leap")                if ($output_containers =~ m/Untagged: opensuse\/leap/);
    die("error: $runtime image rmi -a opensuse/tumbleweed")          if ($output_containers =~ m/Untagged: opensuse\/tumbleweed/);
    die("error: $runtime image rmi -a tw:saved")                     if ($output_containers =~ m/Untagged: tw:saved/);
    die("error: $runtime image rmi -a alpine:$alpine_image_version") if ($output_containers =~ m/Untagged: alpine:$alpine_image_version/);
    die("error: $runtime image rmi -a hello-world:latest")           if ($output_containers =~ m/Untagged: hello-world:latest/);
}

# Setup environment
sub set_up {
    my $dir = shift;
    die "You must define the directory!" unless $dir;

    assert_script_run("mkdir -p $dir/BuildTest");
    assert_script_run "curl -f -v " . data_url('containers/app.py') . " > $dir/BuildTest/app.py";
    assert_script_run "curl -f -v " . data_url('containers/Dockerfile') . " > $dir/BuildTest/Dockerfile";
    assert_script_run "curl -f -v " . data_url('containers/requirements.txt') . " > $dir/BuildTest/requirements.txt";
}

# Build the image
sub build_img {
    my $dir = shift;
    die "You must define the directory!" unless $dir;
    my $runtime = shift;
    die "You must define the runtime!" unless $runtime;

    assert_script_run("cd $dir");
    assert_script_run("$runtime pull python:3", timeout => 300);
    assert_script_run("$runtime build -t myapp BuildTest");
    assert_script_run("$runtime images| grep myapp");
}

# Run the built image
sub test_built_img {
    my $runtime = shift;
    die "You must define the runtime!" unless $runtime;

    assert_script_run("mkdir /root/templates");
    assert_script_run "curl -f -v " . data_url('containers/index.html') . " > /root/templates/index.html";
    assert_script_run("$runtime run -dit -p 8888:5000 -v ~/templates:\/usr/src/app/templates myapp www.google.com");
    sleep 5;
    assert_script_run("$runtime ps -a");
    assert_script_run('curl http://localhost:8888/ | grep "Networking test shall pass"');
    assert_script_run("rm -rf /root/templates");
}
1;
