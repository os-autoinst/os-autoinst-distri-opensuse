# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: seccomp
# Summary: Test seccomp in docker & podman
# Maintainer: QE-C team <qa-c@suse.de>


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

    my $image = "registry.opensuse.org/opensuse/tumbleweed";
    my $policy = "policy.json";

    assert_script_run('curl ' . data_url("containers/$runtime-seccomp.json") . " -o $policy");

    # Run ls command
    assert_script_run "$runtime run --rm --security-opt seccomp=$policy $image ls >/dev/null";
    # Remove syscalls needed to get directory entries
    assert_script_run "sed -i -e 's/\"getdents\",//' -e 's/\"getdents64\",//' $policy";
    assert_script_run "! $runtime run --rm --security-opt seccomp=$policy $image ls >/dev/null";

    assert_script_run "$runtime run --rm --security-opt seccomp=unconfined $image ls >/dev/null";
}

1;

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
