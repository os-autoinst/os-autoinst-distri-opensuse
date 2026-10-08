# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: conmon
# Summary: Upstream conmon integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use version;
use containers::bats;

sub run_tests {
    my %params = @_;
    my ($rootless, $oci_runtime) = ($params{rootless}, $params{oci_runtime});

    my %env = (
        CONMON_BINARY => "/usr/bin/conmon",
        RUNTIME_BINARY => "/usr/bin/$oci_runtime",
    );

    my $log_file = "conmon-$oci_runtime-" . ($rootless ? "user" : "root");

    my @xfails = ();

    return bats_tests($log_file, \%env, \@xfails, 800);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(binutils conmon podman socat);
    my @oci_runtimes = split(/\s+/, get_var("OCI_RUNTIME", is_sle ? "runc" : "crun runc"));
    push @pkgs, @oci_runtimes;

    $self->setup_pkgs(@pkgs);

    my $conmon_version = script_output("conmon --version | awk '/version/ { print \$3 }'");
    record_info("conmon version", $conmon_version);
    record_info("conmon package version", script_output("rpm -q conmon"));

    switch_to_user;

    # Download conmon sources
    patch_sources "conmon", "v$conmon_version", "test";

    my $errors = 0;

    unless (check_var("BATS_IGNORE_USER", "all")) {
        foreach my $oci_runtime (@oci_runtimes) {
            $errors += run_tests(rootless => 1, oci_runtime => $oci_runtime);
        }
    }

    switch_to_root;

    unless (check_var("BATS_IGNORE_USER", "all")) {
        foreach my $oci_runtime (@oci_runtimes) {
            $errors += run_tests(rootless => 0, oci_runtime => $oci_runtime);
        }
    }

    die "conmon tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
