# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: runc
# Summary: Upstream runc integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use Utils::Architectures;
use containers::bats;

sub run_tests {
    my %params = @_;
    my $rootless = $params{rootless};

    my %env = (
        RUNC_USE_SYSTEMD => "1",
        RUNC => "/usr/bin/runc",
    );

    my $log_file = "runc-" . ($rootless ? "user" : "root");

    my @xfails = ();
    push @xfails, (
        # These tests fail due to:
        # https://github.com/opencontainers/runc/issues/4732
        "run.bats::runc run [joining existing container namespaces]",
        "userns.bats::userns join other container userns",
    ) if (is_sle("<16") && $rootless);

    return bats_tests($log_file, \%env, \@xfails, 1200);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(glibc-devel-static go1.24 libseccomp-devel make runc);
    push @pkgs, "criu" if is_tumbleweed;

    $self->setup_pkgs(@pkgs);

    record_info("runc version", script_output("runc --version"));
    record_info("runc features", script_output("runc features"));
    record_info("runc package version", script_output("rpm -q runc"));

    switch_to_user;

    # Download runc sources
    my $runc_version = script_output "runc --version  | awk '{ print \$3 }'";
    patch_sources "runc", "v$runc_version", "tests/integration";

    # Compile helpers used by the tests
    my $helpers = script_output "find contrib/cmd tests/cmd -mindepth 1 -maxdepth 1 -type d ! -name _bin -printf '%f ' || true";
    record_info("helpers", $helpers);
    run_command "make $helpers || true";

    unless (get_var("RUN_TESTS")) {
        # Skip this test due to https://bugzilla.suse.com/show_bug.cgi?id=1247568
        run_command "rm -f tests/integration/no_pivot.bats" if is_ppc64le;
        # Skip this test due to https://bugzilla.suse.com/show_bug.cgi?id=1247567
        run_command "rm -f tests/integration/seccomp.bats" if is_s390x;
    }

    my $errors = 0;
    $errors += run_tests(rootless => 1) unless check_var('BATS_IGNORE_USER', 'all');

    switch_to_root;

    $errors += run_tests(rootless => 0) unless check_var('BATS_IGNORE_ROOT', 'all');

    die "runc tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
