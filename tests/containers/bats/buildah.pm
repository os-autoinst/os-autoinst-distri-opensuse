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
use utils qw(script_retry);
use containers::common;
use containers::bats;

my $test_dir = "/var/tmp/buildah-tests";

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

    script_run 'podman rm -vf $(podman ps -aq --external)';
    assert_script_run "podman system reset -f";
    assert_script_run "buildah prune -a -f";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(buildah docker git-core git-daemon glibc-devel-static go jq libgpgme-devel libseccomp-devel make openssl podman selinux-tools);

    $self->bats_setup(@pkgs);

    record_info("buildah version", script_output("buildah --version"));
    record_info("buildah info", script_output("buildah info"));
    record_info("buildah package version", script_output("rpm -q buildah"));

    switch_to_user;

    record_info("buildah rootless", script_output("buildah info"));

    # Download buildah sources
    my $buildah_version = script_output "buildah --version | awk '{ print \$3 }'";
    my $url = get_var("BATS_URL", "https://github.com/containers/buildah/archive/refs/tags/v$buildah_version.tar.gz");
    assert_script_run "mkdir -p $test_dir";
    selinux_hack $test_dir;
    selinux_hack "/tmp";
    assert_script_run "cd $test_dir";
    script_retry("curl -sL $url | tar -zxf - --strip-components 1", retry => 5, delay => 60, timeout => 300);

    # Patch mkdir to always use -p
    assert_script_run "sed -i 's/ mkdir /& -p /' tests/*.bats tests/helpers.bash";

    # Compile helpers used by the tests
    my $helpers = script_output 'echo $(grep ^all: Makefile | grep -o "bin/[a-z]*" | grep -v bin/buildah)';
    assert_script_run "make $helpers", timeout => 600;

    my $errors = run_tests(rootless => 1, skip_tests => get_var('BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run "cd $test_dir";

    $errors += run_tests(rootless => 0, skip_tests => get_var('BATS_SKIP_ROOT', ''));

    die "buildah tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook $test_dir;
}

sub post_run_hook {
    bats_post_hook $test_dir;
}

1;
