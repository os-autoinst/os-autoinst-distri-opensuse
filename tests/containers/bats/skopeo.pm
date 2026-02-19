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
    # We can't use openSUSE's distribution-registry package on SLES so extract this binary from the OCI image
    # Note: registry:latest with v3 fails unlike library/registry:3
    run_command "podman run --rm -v /usr/local/bin:/target:rw,z --user root --entrypoint /bin/cp $registry /bin/registry /target/";
    run_command '(cd integration; SKOPEO_BINARY=/usr/bin/skopeo gotestsum --junitfile ../integration.xml --format standard-verbose --)', timeout => 300;
    patch_junit "skopeo", $skopeo_version, "integration.xml";
    parse_extra_log(XUnit => "integration.xml");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(apache2-utils go1.25 openssl podman squashfs skopeo);
    push @pkgs, "fakeroot" unless (is_sle('>=16.0') || (is_sle(">=15-SP6") && is_s390x));
    # Packages needed for Golang integration tests
    push @pkgs, qw(libgpgme-devel) if (is_tumbleweed && is_x86_64);

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

    test_integration if (is_tumbleweed && is_x86_64);

    die "skopeo tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
