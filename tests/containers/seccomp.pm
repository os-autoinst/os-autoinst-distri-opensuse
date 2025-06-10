# SUSE's openQA tests
#
# Copyright 2024,2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: seccomp
# Summary: Test seccomp in docker & podman
# Maintainer: QE-C team <qa-c@suse.de>


use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils;
use containers::common;

my $engine;

sub run {
    my ($self, $args) = @_;
    my $runtime = $args->{runtime};

    select_serial_terminal;
    $engine = $self->containers_factory($runtime);

    assert_script_run "grep SECCOMP /boot/config-\$(uname -r)";
    assert_script_run "$runtime info | grep -i seccomp";

    # busybox ls doesn't handle readdir failure, so use something with coreutils inside.
    # Note that there can also be a kind of false negative: with runc, the seccomp policy
    # breaks runc even before it reaches ls.
    my $image = get_var("CONTAINER_IMAGE_TO_TEST", "registry.opensuse.org/opensuse/tumbleweed:latest");
    my $policy = "policy.json";

    assert_script_run('curl ' . data_url("containers/$runtime-seccomp.json") . " -o $policy");

    script_retry("$runtime pull $image", timeout => 300, delay => 60, retry => 3);

    # Verify ls works with that policy
    validate_script_output "$runtime run --rm --security-opt seccomp=$policy $image ls", qr/proc/;
    # Verify it fails if syscalls needed to get directory entries get denied
    assert_script_run "sed -i -e 's/\"getdents\",//' -e 's/\"getdents64\",//' $policy";
    assert_script_run "! $runtime run --rm --security-opt seccomp=$policy $image ls";

    validate_script_output "$runtime run --rm --security-opt seccomp=unconfined $image ls", qr/proc/;
}

sub cleanup() {
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_run_hook;
}

1;
