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
use version;
use Utils::Architectures;
use containers::bats;

sub run_tests {
    my %params = @_;
    my $rootless = $params{rootless};

    my %env = (
        RUNC => "/usr/bin/runc",
    );
    # systemd cgroups manager only works on cgroup v2
    $env{RUNC_USE_SYSTEMD} = "1" if (script_run("test -f /sys/fs/cgroup/cgroup.controllers") == 0);

    if ($rootless && !is_sle("<15-SP6")) {
        # /etc/subgid is keyed by user, not group
        my ($gid_start, $gid_len) = split / /, script_output(
            q(awk -F: -v user="$(id -un)" '$1 == user { print $2, $3; exit }' /etc/subgid)
        );
        my ($uid_start, $uid_len) = split / /, script_output(
            q(awk -F: -v user="$(id -un)" '$1 == user { print $2, $3; exit }' /etc/subuid)
        );
        $env{ROOTLESS_FEATURES} = "idmap";
        $env{ROOTLESS_GIDMAP_START} = $gid_start;
        $env{ROOTLESS_GIDMAP_LENGTH} = $gid_len;
        $env{ROOTLESS_UIDMAP_START} = $uid_start;
        $env{ROOTLESS_UIDMAP_LENGTH} = $uid_len;
    }

    my $log_file = "runc-" . ($rootless ? "user" : "root");

    my @xfails = ();
    push @xfails, (
        # These tests fail due to:
        # https://github.com/opencontainers/runc/issues/4732
        "run.bats::runc run [joining existing container namespaces]",
        "userns.bats::userns join other container userns",
    ) if (is_sle("<16") && $rootless);
    # NOTE: Remove when criu > 4.2-2.1
    push @xfails, (
        "checkpoint.bats::checkpoint --lazy-pages and restore",
        "checkpoint.bats::checkpoint --pre-dump and restore",
        "checkpoint.bats::checkpoint and restore",
        "checkpoint.bats::checkpoint and restore (bind mount, destination is symlink)",
        "checkpoint.bats::checkpoint and restore (with --debug)",
        "checkpoint.bats::checkpoint and restore in external network namespace",
        "checkpoint.bats::checkpoint and restore with container specific CRIU config",
        "checkpoint.bats::checkpoint and restore with nested bind mounts",
        "checkpoint.bats::checkpoint and restore with netdevice",
        "checkpoint.bats::checkpoint and restore with netdevice (bind mount, destination is symlink)",
        "checkpoint.bats::checkpoint and restore with netdevice (with --debug)",
        "checkpoint.bats::checkpoint then restore into a different cgroup (via --manage-cgroups-mode ignore)",
        "checkpoint.bats::checkpoint/restore and exec",
    ) if (is_tumbleweed);

    return bats_tests($log_file, \%env, \@xfails, 3000);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(glibc-devel-static go1.26 libseccomp-devel make runc);
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
