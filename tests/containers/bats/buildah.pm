# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: buildah
# Summary: Upstream buildah integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::bats;


sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $storage_driver = get_var("BUILDAH_STORAGE_DRIVER", script_output("buildah info --format '{{ .store.GraphDriverName }}'"));
    record_info("storage driver", $storage_driver);

    my $oci_runtime = get_var('OCI_RUNTIME', script_output("buildah info --format '{{ .host.OCIRuntime }}'"));

    my %env = (
        BUILDAH_BINARY => "/usr/bin/buildah",
        BUILDAH_RUNTIME => $oci_runtime,
        CI_DESIRED_RUNTIME => $oci_runtime,
        STORAGE_DRIVER => $storage_driver,
    );

    my $log_file = "buildah-" . ($rootless ? "user" : "root") . ".tap";

    my $ret = bats_tests($log_file, \%env, $skip_tests);

    run_command 'podman rm -vf $(podman ps -aq --external) || true';
    run_command "podman system reset -f";
    run_command "buildah prune -a -f";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(buildah docker git-core git-daemon glibc-devel-static go1.24 jq libgpgme-devel libseccomp-devel make openssl podman selinux-tools);

    $self->bats_setup(@pkgs);

    record_info("buildah version", script_output("buildah --version"));
    record_info("buildah info", script_output("buildah info"));
    record_info("buildah package version", script_output("rpm -q buildah"));

    switch_to_user;

    record_info("buildah rootless", script_output("buildah info"));

    # Download buildah sources
    my $buildah_version = script_output "buildah --version | awk '{ print \$3 }'";
    bats_sources $buildah_version;
    bats_patches;

    # Patch mkdir to always use -p
    run_command "sed -i 's/ mkdir /& -p /' tests/*.bats tests/helpers.bash";

    # Compile helpers used by the tests
    my $helpers = script_output 'echo $(grep ^all: Makefile | grep -o "bin/[a-z]*" | grep -v bin/buildah)';
    run_command "make $helpers", timeout => 600;

    my $errors = run_tests(rootless => 1, skip_tests => get_var('BATS_SKIP_USER', ''));

    switch_to_root;

    $errors += run_tests(rootless => 0, skip_tests => get_var('BATS_SKIP_ROOT', ''));

    die "buildah tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
