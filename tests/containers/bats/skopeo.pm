# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: skopeo
# Summary: Upstream skopeo integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures qw(is_x86_64);
use containers::bats;
use version_utils qw(is_sle);


sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if check_var($skip_tests, "all");

    # Default quay.io/libpod/registry:2 image used by the test only has amd64 image
    my $registry = is_x86_64 ? "" : "docker.io/library/registry:2";

    my %env = (
        SKOPEO_BINARY => "/usr/bin/skopeo",
        SKOPEO_TEST_REGISTRY_FQIN => $registry,
    );

    my $log_file = "skopeo-" . ($rootless ? "user" : "root") . ".tap";

    return bats_tests($log_file, \%env, $skip_tests);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(apache2-utils jq openssl podman squashfs skopeo);
    push @pkgs, "fakeroot" unless is_sle('>=16.0');

    $self->bats_setup(@pkgs);

    record_info("skopeo version", script_output("skopeo --version"));
    record_info("skopeo package version", script_output("rpm -q skopeo"));

    # Download skopeo sources
    my $skopeo_version = script_output "skopeo --version  | awk '{ print \$3 }'";
    bats_sources $skopeo_version;

    # Upstream script gets GOARCH by calling `go env GOARCH`.  Drop go dependency for this only use of go
    my $goarch = script_output "podman version -f '{{.OsArch}}' | cut -d/ -f2";
    run_command "sed -i 's/arch=.*/arch=$goarch/' systemtest/010-inspect.bats";

    my $errors = run_tests(rootless => 1, skip_tests => 'BATS_SKIP_USER');

    switch_to_root;

    $errors += run_tests(rootless => 0, skip_tests => 'BATS_SKIP_ROOT');

    die "skopeo tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
