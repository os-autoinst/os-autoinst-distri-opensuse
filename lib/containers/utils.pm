# SUSE's openQA tests
#
# Copyright 2020-2024 SUSE LLC
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

our @EXPORT = qw(runtime_smoke_tests get_vars
  can_build_sle_base get_docker_version get_podman_version check_runtime_version
  check_min_runtime_version container_ip container_route registry_url reset_container_network_if_needed
);

sub get_docker_version {
    my $raw = script_output("docker --version");
    my ($v, undef) = split(',', $raw);
    my @all = $v =~ /(\d+)/g;
    $v = join('.', @all);
    record_info "Docker version", "$v";
    return $v;
}

sub get_podman_version {
    return script_output "podman version | awk '/^Version:/ { print \$2 }'";
}

sub check_runtime_version {
    my ($current, $other) = @_;
    return check_version($other, $current, qr/\d{2}(?:\.\d+)/);
}

sub check_min_runtime_version {
    my ($desired_version) = @_;
    my $podman_version = get_podman_version();
    return version->parse($podman_version) >= version->parse($desired_version);
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
        my $version = get_podman_version();
        if (package_version_cmp($version, '4.3.0') <= 0) {
            record_info("SKIP", "The update command is not supported on podman $version");
            return;
        }
    } elsif ($runtime ne 'docker') {
        record_info("SKIP", "The update command is not supported on $runtime");
        return;
    }

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
