# SUSE's openQA tests
#
# Copyright 2020-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic functions for testing docker
# Maintainer: qac team <qa-c@suse.de>

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

our @EXPORT = qw(runtime_smoke_tests get_vars
  check_min_runtime_version container_ip container_route registry_url reset_container_network_if_needed
);

sub check_min_runtime_version {
    my ($desired_version) = @_;
    my $podman_version = script_output "podman version | awk '/^Version:/ { print \$2 }'";
    return version->parse($podman_version) >= version->parse($desired_version);
}


sub container_ip {
    my ($container, $runtime) = @_;
    my $format = ($runtime eq "podman") ? ".NetworkSettings.IPAddress" : ".NetworkSettings.Networks.bridge.IPAddress";
    my $ip = script_output "$runtime inspect $container --format='{{$format}}'";
    record_info "container IP", "$ip";
    return $ip;
}

sub container_route {
    my ($container, $runtime) = @_;
    my $format = ($runtime eq "podman") ? ".NetworkSettings.Gateway" : ".NetworkSettings.Networks.bridge.Gateway";
    my $route = script_output "$runtime inspect $container --format='{{$format}}'";
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

    my $old_value = script_output "$runtime container inspect -f '{{.HostConfig.CpuShares}}' $container";
    die "Default for cpu-shares != 0" if ($old_value != 0);

    my $try_value = 512;

    assert_script_run "$runtime update --cpu-shares $try_value $container";

    my $new_value = script_output "$runtime container inspect -f '{{.HostConfig.CpuShares}}' $container";

    if ($try_value != $new_value) {
        if ($runtime eq 'podman') {
            # NOTE: Remove block when https://github.com/containers/podman/issues/17187 is solved
            my $id = script_output "podman container inspect -f '{{.Id}}' $container";
            my $cpu_weight = "cat /sys/fs/cgroup/machine.slice/libpod-$id.scope/cpu.weight";
            die "$runtime update failed for cpu-shares: $cpu_weight" if $cpu_weight == 100;
        } else {
            die "$runtime update failed for cpu-shares: $try_value != $new_value";
        }
    }
}

# This is simple and universal
sub runtime_smoke_tests {
    my %args = @_;
    my $runtime = $args{runtime};
    my $image = $args{image} // "registry.opensuse.org/opensuse/busybox:latest";

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
        test_update_cmd(runtime => $runtime, container => 'sleeper') unless ($runtime eq "nerdctl");

        # Stop the container
        assert_script_run("$runtime stop sleeper");

        # Remove the container
        assert_script_run("$runtime rm sleeper");
    }

    # Remove the image we pulled
    assert_script_run("$runtime rmi $image");
}

sub reset_container_network_if_needed {
    my ($current_engine) = @_;
    my ($version, $sp, $host_distri) = get_os_release;
    my $sp_version = "$version.$sp";

    # This workaround is only needed from SLE 15-SP3 (and Leap 15.3) onwards.
    # See https://bugzilla.suse.com/show_bug.cgi?id=1213811
    if ($version eq "15" && $sp >= 3) {
        my $runtime = get_required_var('CONTAINER_RUNTIMES');
        if ($host_distri =~ /sles|opensuse/ && $runtime =~ /docker/) {
            if ($current_engine eq 'podman') {
                # Only stop docker, if docker is active. This is also a free check if docker is present
                systemctl("stop docker") if (script_run("systemctl is-active docker") == 0);
            } elsif ($current_engine eq 'docker') {
                systemctl("start docker");
            }
            systemctl("restart firewalld") if (script_run("systemctl is-active firewalld") == 0);
        }
    }
}

1;
