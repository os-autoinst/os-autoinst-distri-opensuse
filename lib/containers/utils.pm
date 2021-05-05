# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
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
use Mojo::Util 'trim';

our @EXPORT = qw(test_seccomp basic_container_tests container_set_up get_vars build_img test_built_img can_build_sle_base check_docker_firewall get_docker_version check_runtime_version container_ip);

sub test_seccomp {
    my $no_seccomp = script_run('docker info | tee /tmp/docker_info.txt | grep seccomp');
    upload_logs('/tmp/docker_info.txt');
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

sub check_docker_firewall {
    my $container_name = 'sut_container';
    my $running        = script_output qq(docker ps -a -q | wc -l);
    validate_script_output('ip a s docker0', sub { /state DOWN/ }) if $running != 0;
    assert_script_run "firewall-cmd --list-all --zone=docker";
    validate_script_output "firewall-cmd --list-interfaces --zone=docker",  sub { /docker0/ };
    validate_script_output "firewall-cmd --list-interfaces --zone=trusted", sub { /^\s*$/ };
    # Rules applied before DOCKER. Default is to listen to all tcp connections
    # ex. output: "1           0        0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0"
    validate_script_output "iptables -L DOCKER-USER -nvx --line-numbers", sub { /1.+all.+0\.0\.0\.0\/0\s+0\.0\.0\.0\/0/ };
    assert_script_run "docker run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine');
    my $container_ip = container_ip($container_name, "docker");
    # Each running container should have added a new entry to the DOCKER zone.
    # ex. output: "1           0        0 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:1234"
    validate_script_output "iptables -L DOCKER -nvx --line-numbers", sub { /1.+ACCEPT.+!docker0 docker0.+$container_ip\s+tcp dpt:1234/ };
    assert_script_run "docker kill $container_name ";
}

sub get_docker_version {
    my $v = script_output("docker --version");
    record_info "$v", $v =~ /(\d{2}\.\d{2})/;
    return $v =~ /(\d{2}\.\d{2})/;
}

sub check_runtime_version {
    my ($current, $other) = @_;
    return check_version($other, $current, qr/\d{2}(?:\.\d+)/);
}

sub container_ip {
    my ($container, $runtime) = @_;
    my $ip = script_output "$runtime inspect $container --format='{{.NetworkSettings.IPAddress}}'";
    record_info "$ip";
    return $ip;
}

sub basic_container_tests {
    my %args    = @_;
    my $runtime = $args{runtime};
    die "You must define the runtime!" unless $runtime;
    my $alpine_image_version = '3.6';
    my $alpine               = registry_url('alpine', $alpine_image_version);
    my $hello_world          = registry_url('hello-world');
    my $leap                 = "registry.opensuse.org/opensuse/leap";
    my $tumbleweed           = "registry.opensuse.org/opensuse/tumbleweed";

    # Test search feature
    validate_script_output("$runtime search --no-trunc tumbleweed", sub { m/Official openSUSE Tumbleweed images/ });

    #   - pull minimalistic alpine image of declared version using tag
    #   - https://store.docker.com/images/alpine
    assert_script_run("$runtime image pull $alpine", timeout => 300);
    #   - pull typical docker demo image without tag. Should be latest.
    #   - https://store.docker.com/images/hello-world
    assert_script_run("$runtime image pull $hello_world", timeout => 300);
    #   - pull image of last released version of openSUSE Leap
    if (!check_var('ARCH', 's390x')) {
        assert_script_run("$runtime image pull $leap", timeout => 600);
    } else {
        record_soft_failure("bsc#1171672 Missing Leap:latest container image for s390x");
    }
    #   - pull image of openSUSE Tumbleweed
    assert_script_run("$runtime image pull $tumbleweed", timeout => 600);

    # All images can be listed
    assert_script_run("$runtime image ls");
    # Local images can be listed
    assert_script_run("$runtime image ls none");
    #   - filter with tag
    assert_script_run(qq{$runtime image ls $alpine | grep "alpine\\s*$alpine_image_version"});
    #   - filter without tag
    assert_script_run(qq{$runtime image ls $hello_world | grep "hello-world\\s*latest"});
    #   - all local images
    my $local_images_list = script_output("$runtime image ls");
    die("$runtime image $tumbleweed not found") unless ($local_images_list =~ /opensuse\/tumbleweed\s*latest/);
    die("$runtime image $leap not found") if (!check_var('ARCH', 's390x') && !$local_images_list =~ /opensuse\/leap\s*latest/);

    # Containers can be spawned
    #   - using 'run'
    assert_script_run("$runtime container run --name test_1 $hello_world | grep 'Hello from Docker\!'");
    #   - using 'create', 'start' and 'logs' (background container)
    assert_script_run("$runtime container create --name test_2 $alpine /bin/echo Hello world");
    assert_script_run("$runtime container start test_2 | grep test_2");
    assert_script_run("$runtime container logs test_2 | grep 'Hello world'");
    #   - using 'run --rm'
    assert_script_run(qq{$runtime container run --name test_ephemeral --rm $alpine /bin/echo Hello world | grep "Hello world"});
    #   - using 'run -d' and 'inspect' (background container)
    my $container_name = 'tw';
    assert_script_run("$runtime container run -d --name $container_name $tumbleweed tail -f /dev/null");
    assert_script_run("$runtime container inspect --format='{{.State.Running}}' $container_name | grep true");
    my $output_containers = script_output("$runtime container ls -a");
    die('error: missing container test_1') unless ($output_containers =~ m/test_1/);
    die('error: missing container test_2') unless ($output_containers =~ m/test_2/);
    die('error: ephemeral container was not removed') if ($output_containers =~ m/test_ephemeral/);
    die("error: missing container $container_name") unless ($output_containers =~ m/$container_name/);

    # Containers' state can be saved to a docker image
    if (script_run("$runtime container exec $container_name zypper -n in curl", 300)) {
        record_info('poo#40958 - curl install failure, try with force-resolution.');
        my $output = script_output("$runtime container exec $container_name zypper in --force-resolution -y -n curl", 600);
        die('error: curl not installed in the container') unless (($output =~ m/Installing: curl.*done/) || ($output =~ m/\'curl\' .* already installed/));
    }
    assert_script_run("$runtime container commit $container_name tw:saved", 240);

    # Network is working inside of the containers
    my $output = script_output("$runtime container run tw:saved curl -I google.de");
    die("network is not working inside of the container tw:saved") unless ($output =~ m{Location: http://www\.google\.de/});

    # Using an init process as PID 1
    assert_script_run "$runtime run --rm --init $tumbleweed ps --no-headers -xo 'pid args' | grep '1 .*init'";

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
    die("error: $runtime image rmi -a $leap")                               if ($output_containers =~ m/Untagged:.*opensuse\/leap/);
    die("error: $runtime image rmi -a $tumbleweed")                         if ($output_containers =~ m/Untagged:.*opensuse\/tumbleweed/);
    die("error: $runtime image rmi -a tw:saved")                            if ($output_containers =~ m/Untagged:.*tw:saved/);
    record_soft_failure("error: $runtime image rmi -a $alpine")             if ($output_containers =~ m/Untagged:.*alpine/);
    record_soft_failure("error: $runtime image rmi -a $hello_world:latest") if ($output_containers =~ m/Untagged:.*hello-world:latest/);
}

# Setup environment
sub container_set_up {
    my ($dir, $file, $base) = @_;
    die "You must define the directory!"  unless $dir;
    die "You must define the Dockerfile!" unless $file;

    record_info('Downloading', "Dockerfile: containers/$file\nApplication: containers/app.py\nRequirements: containers/requirements.txt\nTemplate: containers/index.html");
    assert_script_run "mkdir -p $dir/BuildTest/templates";
    assert_script_run "curl -f -v " . data_url('containers/app.py') . " > $dir/BuildTest/app.py";
    assert_script_run "curl -f -v " . data_url("containers/$file") . " > $dir/BuildTest/Dockerfile";
    file_content_replace("$dir/BuildTest/Dockerfile", baseimage_var => $base) if defined $base;
    assert_script_run "curl -f -v " . data_url('containers/requirements.txt') . " > $dir/BuildTest/requirements.txt";
    assert_script_run "curl -f -v " . data_url('containers/index.html') . " > $dir/BuildTest/templates/index.html";
}

# Build the image
sub build_img {
    my $dir = shift;
    die "You must define the directory!" unless $dir;
    my $runtime = shift;
    die "You must define the runtime!" unless $runtime;
    my $py_repo = get_var('REGISTRY', 'docker.io');

    assert_script_run("cd $dir");
    if ($runtime =~ /docker|podman/) {
        assert_script_run("$runtime image pull $py_repo", timeout => 300);
        assert_script_run("$runtime tag $py_repo python:3");
        assert_script_run("$runtime build -t myapp BuildTest");
    }
    elsif ($runtime =~ /buildah/) {
        assert_script_run("$runtime bud -t myapp BuildTest");
    }
    else {
        die "Unsupported runtime: $runtime";
    }
    assert_script_run("cd");
    assert_script_run("$runtime images| grep myapp");
}

# Run the built image
sub test_built_img {
    my $runtime = shift;
    die "You must define the runtime!" unless $runtime;

    assert_script_run("$runtime run -dit -p 8888:5000 myapp www.google.com");
    sleep 5;
    assert_script_run("$runtime ps -a");
    script_retry('curl http://localhost:8888/ | grep "Networking test shall pass"', delay => 5, retry => 6);
    assert_script_run("rm -rf /root/templates");
}

=head2 can_build_sle_base

C<can_build_sle_base> should be used to identify if sle base image runs against a
system that it does not support registration and SUSEConnect.
In this case the build of the base image is not going to work as it lacks the repositories

The call should return false if the test is run on a non-sle host.

=cut
sub can_build_sle_base {
    # script_run returns 0 if true, but true is 1 on perl
    my $has_sle_registration = !script_run("test -e /etc/zypp/credentials.d/SCCcredentials");
    return check_os_release('sles', 'ID') && $has_sle_registration;
}

1;
