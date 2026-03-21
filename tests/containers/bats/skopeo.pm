# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: skopeo
# Summary: Upstream skopeo integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures;
use version_utils;
use version;
use containers::bats;

my $skopeo_version;
# Default quay.io/libpod/registry:2 image used by the tests only has amd64 image
my $registry = "registry.opensuse.org/opensuse/registry:2";

sub run_tests {
    my %params = @_;
    my $rootless = $params{rootless};

    my %env = (
        SKOPEO_BINARY => "/usr/bin/skopeo",
        SKOPEO_TEST_REGISTRY_FQIN => $registry,
    );

    my $log_file = "skopeo-" . ($rootless ? "user" : "root");

    my @xfails = ();

    return bats_tests($log_file, \%env, \@xfails, 800);
}

sub test_integration {
    install_gotestsum;
    run_command "cd integration";
    run_timeout_command "SKOPEO_BINARY=/usr/bin/skopeo gotestsum --junitfile integration.xml --format standard-verbose -- &> integration.txt", no_assert => 1, timeout => 300;
    upload_logs "integration.txt";
    die "Testsuite failed" if script_run("test -s integration.xml");
    patch_junit "skopeo", $skopeo_version, "integration.xml";
    parse_extra_log(XUnit => "integration.xml");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(apache2-utils go1.26 openssl podman squashfs skopeo);
    push @pkgs, "fakeroot" unless (is_sle('>=16.0') || (is_sle(">=15-SP6") && is_s390x));
    # Needed for integration tests
    push @pkgs, qw(distribution-registry libgpgme-devel) unless is_sle;

    $self->setup_pkgs(@pkgs);

    # Prevent https://github.com/containers/skopeo/issues/2718
    run_command "sed -i '/sigstore-staging:/d' /etc/containers/registries.d/default.yaml";

    record_info("skopeo version", script_output("skopeo --version"));
    record_info("skopeo package version", script_output("rpm -q skopeo"));

    switch_to_user;

    # Download skopeo sources
    $skopeo_version = script_output "skopeo --version  | awk '{ print \$3 }'";
    patch_sources "skopeo", "v$skopeo_version", "systemtest";

    my $errors = 0;
    $errors += run_tests(rootless => 1) unless check_var('BATS_IGNORE_USER', 'all');

    switch_to_root;

    $errors += run_tests(rootless => 0) unless check_var('BATS_IGNORE_ROOT', 'all');

    # You need to clone with BATS_IGNORE_USER=all BATS_IGNORE_ROOT=all RUN_TESTS=integration
    test_integration if (check_var("RUN_TESTS", "integration") || is_tumbleweed);

    die "skopeo tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
