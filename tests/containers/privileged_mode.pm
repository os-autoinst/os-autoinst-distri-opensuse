# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test container runtime privileged mode
# Maintainer: qa-c@suse.de

use strict;
use warnings;
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

    my $image = get_var("CONTAINER_IMAGE_TO_TEST", is_opensuse ? "registry.opensuse.org/opensuse/tumbleweed:latest" : "registry.suse.com/bci/bci-base:latest");
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
