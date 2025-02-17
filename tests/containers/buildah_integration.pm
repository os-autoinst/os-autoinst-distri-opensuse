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
use version_utils qw(is_sle);

my $test_dir = "/var/tmp";
my $buildah_version = "";
my $oci_runtime = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $tmp_dir = script_output "mktemp -d -p $test_dir test.XXXXXX";

    my %_env = (
        BUILDAH_BINARY => "/usr/bin/buildah",
        BUILDAH_RUNTIME => $oci_runtime,
        CI_DESIRED_RUNTIME => $oci_runtime,
        STORAGE_DRIVER => "overlay",
        BATS_TMPDIR => $tmp_dir,
        TMPDIR => $tmp_dir,
    );
    my $env = join " ", map { "$_=$_env{$_}" } sort keys %_env;

    my $log_file = "buildah-" . ($rootless ? "user" : "root") . ".tap";
    assert_script_run "echo $log_file .. > $log_file";
    my $ret = script_run "env $env bats --tap tests | tee -a $log_file", 7000;

    my @skip_tests = split(/\s+/, get_var('BUILDAH_BATS_SKIP', '') . " " . $skip_tests);
    patch_logfile($log_file, @skip_tests);
    parse_extra_log(TAP => $log_file);

    script_run 'podman rm -vf $(podman ps -aq --external)';
    assert_script_run "podman system reset -f";
    assert_script_run "buildah prune -a -f";
    script_run "rm -rf $tmp_dir";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(buildah docker git-core git-daemon glibc-devel-static go jq libgpgme-devel libseccomp-devel make openssl podman selinux-tools);
    install_packages(@pkgs);

    $oci_runtime = install_oci_runtime;
    $oci_runtime = script_output "command -v $oci_runtime";

    $self->bats_setup;
    selinux_hack $test_dir;

    record_info("buildah version", script_output("buildah --version"));
    record_info("buildah info", script_output("buildah info"));
    record_info("buildah package version", script_output("rpm -q buildah"));

    switch_to_user;

    assert_script_run "cd $test_dir";

    # Download buildah sources
    $buildah_version = script_output "buildah --version | awk '{ print \$3 }'";
    script_retry("curl -sL https://github.com/containers/buildah/archive/refs/tags/v$buildah_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd $test_dir/buildah-$buildah_version/";

    # Patch mkdir to always use -p
    assert_script_run "sed -i 's/ mkdir /& -p /' tests/*.bats tests/helpers.bash";

    # Compile helpers used by the tests
    my $helpers = script_output 'echo $(grep ^all: Makefile | grep -o "bin/[a-z]*" | grep -v bin/buildah)';
    assert_script_run "make $helpers", timeout => 600;

    my $errors = run_tests(rootless => 1, skip_tests => get_var('BUILDAH_BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir/buildah-$buildah_version/");

    $errors += run_tests(rootless => 0, skip_tests => get_var('BUILDAH_BATS_SKIP_ROOT', ''));

    die "Tests failed" if ($errors);
}

sub cleanup() {
    assert_script_run "cd ~";
    script_run("rm -rf $test_dir/buildah-$buildah_version/");
    bats_post_hook;
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_run_hook;
}

1;
