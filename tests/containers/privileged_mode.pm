# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test container runtime privileged mode
# Maintainer: qa-c@suse.de

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(validate_script_output_retry);
use containers::utils qw(reset_container_network_if_needed registry_url);
use Utils::Architectures;
use Utils::Backends qw(is_xen_pv is_hyperv);
use version_utils qw(is_public_cloud is_sle is_vmware is_opensuse);
use utils qw(script_retry);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    my $runtime = $args->{runtime};
    my $engine = $self->containers_factory($runtime);
    $self->{runtime} = $engine;
    reset_container_network_if_needed($runtime);

    my $image = is_opensuse ? "registry.opensuse.org/opensuse/tumbleweed:latest" : "registry.suse.com/bci/bci-base:latest";
    script_retry("$runtime pull $image", timeout => 300, delay => 120, retry => 3);

    record_info('Test', 'Launch a container with privileged mode');

    my $devices = script_run("$runtime run --rm --privileged $image ls /dev");
    record_info("Devices (privileged)", $devices);
    $devices = script_run("$runtime run --rm $image ls /dev");
    record_info("Devices (unprivileged)", $devices);

    # xen-pv does not define USB passthrough in the xml as of now
    # this feature has to be added -> https://progress.opensuse.org/issues/138410
    assert_script_run("$runtime run --rm $image bash -c '! test -d /dev/bus'");
    assert_script_run("$runtime run --rm --privileged $image ls /dev/bus") unless (is_s390x || is_public_cloud || is_hyperv || is_vmware);

    # syscalls availability
    if ($runtime eq 'podman') {
        script_run("$runtime run --rm -d $image bash -c 'sleep infinity'");
        assert_script_run("$runtime top -l seccomp | grep filter");
        script_run("$runtime run --rm -d --privileged $image bash -c 'sleep infinity'");
        assert_script_run("$runtime top -l seccomp | grep disabled");
    }

    # Mounting tmpfs only works in privileged mode because the read-only protection in the default mode
    assert_script_run("$runtime run --rm --privileged $image mount -t tmpfs none /mnt");

    # check how were kernel filesystem mounted
    assert_script_run("$runtime run --rm $image mount | grep '\(ro'");
    assert_script_run("$runtime run --rm --privileged $image mount | grep '\(rw'");

    # Capabilities are only available in privileged mode
    my $capbnd = script_output("cat /proc/1/status | grep CapBnd");
    validate_script_output("$runtime run --rm --privileged $image cat /proc/1/status | grep CapBnd", sub { m/$capbnd/ });

    # Test container nesting on SLES15+
    # Anything below 12-SP5 is simply too old. 12-SP5 doesn't work because of bsc#1232429
    unless (is_sle('<15') || check_var('BETA', '1')) {
        if ($runtime eq 'docker' && (is_x86_64 || is_aarch64)) {
            # Docker-in-Docker (DinD) uses the special dind image, which is only available for x86_64 and aarch64
            my $dind = registry_url('docker:dind');
            assert_script_run("docker run -d --privileged --name dind $dind");
            script_retry("docker exec -it dind docker run -it $image ls", timeout => 300, retry => 3, delay => 60);  # docker is sometimes not immediately ready
            script_run("docker container stop dind");
            script_run("docker container rm dind");
        } elsif ($runtime eq 'podman') {
            assert_script_run("podman run -d --privileged --name pinp $image sleep infinity");
            assert_script_run("podman exec pinp zypper -n --gpg-auto-import-keys in podman", timeout => 300); # Auto import keys because of the NVIDIA repository on SLES
            assert_script_run("podman exec -it pinp podman run -it $image ls", timeout => 300);
            script_run("podman container stop pinp");
            script_run("podman container rm pinp");
        }
    }
}

sub cleanup {
    my ($self) = @_;
    $self->{runtime}->cleanup_system_host();
}

sub post_run_hook {
    my ($self) = @_;
    $self->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;
    $self->cleanup();
}

1;
