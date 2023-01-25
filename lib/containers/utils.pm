# SUSE's openQA tests
#
# Copyright 2020-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic functions for testing docker
# Maintainer: Anna Minou <anna.minou@suse.de>, qa-c@suse.de

package containers::utils;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use Utils::Architectures;
use utils;
use strict;
use warnings;
use version_utils;
use Mojo::Util 'trim';

our @EXPORT = qw(test_seccomp runtime_smoke_tests basic_container_tests get_vars
  can_build_sle_base get_docker_version check_runtime_version
  container_ip container_route registry_url);

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
    record_info "container IP", "$ip";
    return $ip;
}

sub container_route {
    my ($container, $runtime) = @_;
    my $route = script_output "$runtime inspect $container --format='{{.NetworkSettings.Gateway}}'";
    record_info "container route", "$route";
    return $route;
}

sub registry_url {
    my ($container_name, $version_tag) = @_;
    my $registry = trim(get_var('REGISTRY', 'docker.io'));
    $registry =~ s{/$}{};
    # Images from docker.io registry are listed without the 'docker.io/library/'
    # Images from custom registry are listed with the 'server/library/'
    # We also filter images the same way they are listed.
    my $repo = ($registry =~ /docker\.io/) ? "" : "$registry/library";
    return $registry unless $container_name;
    return sprintf("%s/%s", $repo, $container_name) unless $version_tag;
    return sprintf("%s/%s:%s", $repo, $container_name, $version_tag);
}

sub test_update_cmd {
    my %args = @_;
    my $runtime = $args{runtime};
    my $container = $args{container};

    # podman update was added to v4.3.0
    if ($runtime eq 'podman') {
        my $version = script_output "podman version | awk '/^Version:/ { print \$2 }'";
        if (package_version_cmp($version, '4.3.0') <= 0) {
            record_info("SKIP", "The update command is not supported on podman $version");
            return;
        }
    } elsif ($runtime ne 'docker') {
        record_info("SKIP", "The update command is not supported on $runtime");
        return;
    }

    # The default values for these options are 0.
    # Before adding more options check that they're supported by both podman & docker
    my @opts = ('cpu-shares', 'memory-swap');

    foreach my $opt (@opts) {
        # Transform 'cpu-shares' into 'CpuShares'
        (my $param = $opt) =~ s/^(.)(.*)-(.)(.*)/\u$1$2\u$3$4/;

        my $old_value = script_output "$runtime container inspect -f '{{.HostConfig.$param}}' $container";
        die "Default for $opt != 0" if ($old_value != 0);

        # 10 is the minimum value for blkio-weight
        my $try_value = ($opt eq 'memory-swap') ? -1 : 10;

        assert_script_run "$runtime update --$opt $try_value $container";

        my $new_value = script_output "$runtime container inspect -f '{{.HostConfig.$param}}' $container";

        if ($try_value != $new_value) {
            if ($runtime eq 'podman') {
                record_soft_failure "bsc#1207401, podman update doesn't work";
            } else {
                die "$runtime update failed for $opt: $try_value != $new_value";
            }
        }
    }
}

# This is simple and universal
sub runtime_smoke_tests {
    my %args = @_;
    my $runtime = $args{runtime};
    my $image = $args{image} // registry_url('alpine', '3.6');

    record_info('Smoke', "Smoke test running image: $image on runtime: $runtime.");

    # Pull image from registry
    if ($runtime =~ /nerdctl/) {
        assert_script_run("$runtime image pull --insecure-registry $image");
    } else {
        assert_script_run("$runtime pull $image");
    }

    # List locally available images
    # if we miss $image the test will fail later
    assert_script_run("$runtime image ls");

    # crictl is not implemented as it needs a lot of additional settings just to run container
    if ($runtime !~ /crictl/) {
        # Run container in foreground
        assert_script_run("$runtime run -it --rm $image echo 'Hello'");

        # Run container in background - it can take few seconds
        assert_script_run("$runtime run -d --name 'sleeper' $image sleep 999");
        script_retry("$runtime ps | grep sleeper", delay => 5, retry => 6);

        # Exec command in running container
        assert_script_run("$runtime exec sleeper echo 'Hello'");

        # Test update command
        test_update_cmd(runtime => $runtime, container => 'sleeper');

        # Stop the container
        assert_script_run("$runtime stop sleeper");

        # Remove the container
        assert_script_run("$runtime rm sleeper");
    }

    # Remove the image we pulled
    assert_script_run("$runtime rmi $image");
}

sub basic_container_tests {
    my %args = @_;
    my $runtime = $args{runtime};
    die "You must define the runtime!" unless $runtime;
    my $alpine_image_version = '3.6';
    my $alpine = registry_url('alpine', $alpine_image_version);
    my $hello_world = registry_url('hello-world');
    my $leap = "registry.opensuse.org/opensuse/leap";
    my $tumbleweed = "registry.opensuse.org/opensuse/tumbleweed";

    # Test search feature
    validate_script_output("$runtime search --no-trunc --format \"table {{.Name}} {{.Description}}\" tumbleweed", sub { m/Official openSUSE Tumbleweed images/ }, timeout => 200);
    # This should be conditional based on the needed time, but that's currently not possible.
    record_info('Softfail', 'Searching registry.suse.com is too slow (https://sd.suse.com/servicedesk/customer/portal/1/SD-106252)');

    #   - pull minimalistic alpine image of declared version using tag
    #   - https://store.docker.com/images/alpine
    assert_script_run("$runtime image pull $alpine", timeout => 300);
    #   - pull typical docker demo image without tag. Should be latest.
    #   - https://store.docker.com/images/hello-world
    assert_script_run("$runtime image pull $hello_world", timeout => 300);
    #   - pull image of last released version of openSUSE Leap
    assert_script_run("$runtime image pull $leap", timeout => 600);
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
    die("$runtime image $leap not found") if (!is_s390x && !$local_images_list =~ /opensuse\/leap\s*latest/);

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
    my $ret = script_run("$runtime container exec $container_name zypper -n in curl", 600);
    die('zypper inside container timed out') if (!defined($ret));
    if ($ret != 0) {
        my $output = script_output("$runtime container exec $container_name zypper in --force-resolution -y -n curl", 600);
        die('error: curl not installed in the container') unless (($output =~ m/Installing: curl.*done/) || ($output =~ m/\'curl\' .* already installed/));
    }
    assert_script_run("$runtime container commit $container_name tw:saved", 240);

    # Network is working inside of the containers
    my $output = script_output("$runtime container run tw:saved curl -sI google.de");
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
    die("error: $runtime image rmi -a $leap") if ($output_containers =~ m/Untagged:.*opensuse\/leap/);
    die("error: $runtime image rmi -a $tumbleweed") if ($output_containers =~ m/Untagged:.*opensuse\/tumbleweed/);
    die("error: $runtime image rmi -a tw:saved") if ($output_containers =~ m/Untagged:.*tw:saved/);
    record_info('Softfail', "error: $runtime image rmi -a $alpine", result => 'softfail') if ($output_containers =~ m/Untagged:.*alpine/);
    record_info('Softfail', "error: $runtime image rmi -a $hello_world:latest", result => 'softfail') if ($output_containers =~ m/Untagged:.*hello-world:latest/);
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
