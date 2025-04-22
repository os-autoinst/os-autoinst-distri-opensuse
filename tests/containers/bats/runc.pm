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
use utils qw(script_retry);
use containers::bats;
use version_utils qw(is_tumbleweed);

my $test_dir = "/var/tmp/runc-tests";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my %env = (
        RUNC_USE_SYSTEMD => "1",
        RUNC => "/usr/bin/runc",
    );

    my $log_file = "runc-" . ($rootless ? "user" : "root") . ".tap";

    return bats_tests($log_file, \%env, $skip_tests);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(git-core glibc-devel-static go jq libseccomp-devel make runc);
    push @pkgs, "criu" if is_tumbleweed;

    $self->bats_setup(@pkgs);

    record_info("runc version", script_output("runc --version"));
    record_info("runc features", script_output("runc features"));
    record_info("runc package version", script_output("rpm -q runc"));

    switch_to_user;

    # Download runc sources
    my $runc_version = script_output "runc --version  | awk '{ print \$3 }'";
    my $url = get_var("BATS_URL", "https://github.com/opencontainers/runc/archive/refs/tags/v$runc_version.tar.gz");
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "cd $test_dir";
    script_retry("curl -sL $url | tar -zxf - --strip-components 1", retry => 5, delay => 60, timeout => 300);

    # Compile helpers used by the tests
    my $cmds = script_output "find contrib/cmd tests/cmd -mindepth 1 -maxdepth 1 -type d -printf '%f ' || true";
    script_run "make $cmds";

    my $errors = run_tests(rootless => 1, skip_tests => get_var('BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run "cd $test_dir";

    $errors += run_tests(rootless => 0, skip_tests => get_var('BATS_SKIP_ROOT', ''));

    die "runc tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook $test_dir;
}

sub post_run_hook {
    bats_post_hook $test_dir;
}

1;
