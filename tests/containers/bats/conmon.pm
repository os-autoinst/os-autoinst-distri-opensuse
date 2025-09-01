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
use containers::bats;

my $oci_runtime;

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return 0 if check_var($skip_tests, "all");

    my %env = (
        CONMON_BINARY => "/usr/bin/conmon",
        RUNTIME_BINARY => "/usr/bin/$oci_runtime",
    );

    my $log_file = "conmon-" . ($rootless ? "user" : "root");

    return bats_tests($log_file, \%env, $skip_tests, 800);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(conmon);
    $oci_runtime = get_var("OCI_RUNTIME", "runc");
    push @pkgs, $oci_runtime;

    $self->bats_setup(@pkgs);

    my $conmon_version = script_output("conmon --version | awk '/version/ { print \$3 }'");
    record_info("conmon version", $conmon_version);
    record_info("conmon package version", script_output("rpm -q conmon"));

    # Download conmon sources
    bats_sources $conmon_version;

    my $errors = run_tests(rootless => 1, skip_tests => 'BATS_IGNORE_USER');

    switch_to_root;

    $errors += run_tests(rootless => 0, skip_tests => 'BATS_IGNORE_ROOT');

    die "conmon tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
