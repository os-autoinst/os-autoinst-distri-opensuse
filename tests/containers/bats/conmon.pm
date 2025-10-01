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
use version_utils qw(is_tumbleweed);
use containers::bats;

sub run_tests {
    my %params = @_;
    my ($rootless, $oci_runtime, $skip_tests) = ($params{rootless}, $params{oci_runtime}, $params{skip_tests});

    return 0 if check_var($skip_tests, "all");

    my %env = (
        CONMON_BINARY => "/usr/bin/conmon",
        RUNTIME_BINARY => "/usr/bin/$oci_runtime",
    );

    my $log_file = "conmon-$oci_runtime-" . ($rootless ? "user" : "root");

    return bats_tests($log_file, \%env, $skip_tests, 800);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @oci_runtimes = ();
    my @pkgs = qw(conmon socat);
    if (my $oci_runtime = get_var("OCI_RUNTIME")) {
        push @oci_runtimes, $oci_runtime;
    } else {
        push @oci_runtimes, is_tumbleweed ? qw(crun runc) : qw(runc);
    }
    push @pkgs, @oci_runtimes;

    $self->setup_pkgs(@pkgs);

    my $conmon_version = script_output("conmon --version | awk '/version/ { print \$3 }'");
    record_info("conmon version", $conmon_version);
    record_info("conmon package version", script_output("rpm -q conmon"));

    switch_to_user;

    # Download conmon sources
    patch_sources "conmon", "v$conmon_version", "test";

    my $errors = 0;

    foreach my $oci_runtime (@oci_runtimes) {
        $errors += run_tests(rootless => 1, oci_runtime => $oci_runtime, skip_tests => 'BATS_IGNORE_USER');
    }

    switch_to_root;

    foreach my $oci_runtime (@oci_runtimes) {
        $errors += run_tests(rootless => 0, oci_runtime => $oci_runtime, skip_tests => 'BATS_IGNORE_ROOT');
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
