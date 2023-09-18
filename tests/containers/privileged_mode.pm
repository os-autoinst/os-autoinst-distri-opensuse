# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test container runtime privileged mode
# Maintainer: qa-c@suse.de

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(validate_script_output_retry);
use containers::utils qw(reset_container_network_if_needed);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    my $runtime = $args->{runtime};
    my $engine = $self->containers_factory($runtime);
    $self->{runtime} = $engine;
    reset_container_network_if_needed($runtime);

    my $image = "registry.suse.com/bci/bci-base:latest";

    record_info('Test', 'Launch a container with privileged mode');
    # /dev is only accessible in privileged mode
    assert_script_run("$runtime run --rm --privileged $image ls /dev/bus");

    # Mounting tmpfs only works in privileged mode because the read-only protection in the default mode
    assert_script_run("$runtime run --rm --privileged $image mount -t tmpfs none /mnt");

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
