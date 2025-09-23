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
use containers::bats;
use version_utils qw(is_tumbleweed);
use Utils::Architectures qw(is_ppc64le is_s390x);

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return 0 if check_var($skip_tests, "all");

    my %env = (
        RUNC_USE_SYSTEMD => "1",
        RUNC => "/usr/bin/runc",
    );

    my $log_file = "runc-" . ($rootless ? "user" : "root");

    return bats_tests($log_file, \%env, $skip_tests, 1200);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(glibc-devel-static go1.24 jq libseccomp-devel make runc);
    push @pkgs, "criu" if is_tumbleweed;

    $self->bats_setup(@pkgs);

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

    unless (get_var("BATS_TESTS")) {
        # Skip this test due to https://bugzilla.suse.com/show_bug.cgi?id=1247568
        run_command "rm -f tests/integration/no_pivot.bats" if is_ppc64le;
        # Skip this test due to https://bugzilla.suse.com/show_bug.cgi?id=1247567
        run_command "rm -f tests/integration/seccomp.bats" if is_s390x;
    }

    my $errors = run_tests(rootless => 1, skip_tests => 'BATS_IGNORE_USER');

    switch_to_root;

    $errors += run_tests(rootless => 0, skip_tests => 'BATS_IGNORE_ROOT');

    die "runc tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
