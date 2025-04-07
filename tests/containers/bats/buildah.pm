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

my $test_dir = "/var/tmp/buildah-tests";
my $oci_runtime = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $tmp_dir = script_output "mktemp -d -p /var/tmp test.XXXXXX";
    selinux_hack $tmp_dir;

    my $storage_driver = get_var("BUILDAH_STORAGE_DRIVER", script_output("buildah info --format '{{ .store.GraphDriverName }}'"));
    record_info("storage driver", $storage_driver);

    my %_env = (
        BUILDAH_BINARY => "/usr/bin/buildah",
        BUILDAH_RUNTIME => $oci_runtime,
        CI_DESIRED_RUNTIME => $oci_runtime,
        STORAGE_DRIVER => $storage_driver,
        BATS_TMPDIR => $tmp_dir,
        TMPDIR => $tmp_dir,
        PATH => '/usr/local/bin:$PATH:/usr/sbin:/sbin',
    );
    my $env = join " ", map { "$_=$_env{$_}" } sort keys %_env;

    my $log_file = "buildah-" . ($rootless ? "user" : "root") . ".tap";
    assert_script_run "echo $log_file .. > $log_file";

    my @tests;
    foreach my $test (split(/\s+/, get_var("BUILDAH_BATS_TESTS", ""))) {
        $test .= ".bats" unless $test =~ /\.bats$/;
        push @tests, "tests/$test";
    }
    my $tests = @tests ? join(" ", @tests) : "tests";

    my $ret = script_run "env $env bats --tap $tests | tee -a $log_file", 7000;

    unless (@tests) {
        my @skip_tests = split(/\s+/, get_var('BUILDAH_BATS_SKIP', '') . " " . $skip_tests);
        patch_logfile($log_file, @skip_tests);
    }

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

    record_info("buildah version", script_output("buildah --version"));
    record_info("buildah info", script_output("buildah info"));
    record_info("buildah package version", script_output("rpm -q buildah"));

    switch_to_user;

    record_info("buildah rootless", script_output("buildah info"));

    # Download buildah sources
    my $buildah_version = script_output "buildah --version | awk '{ print \$3 }'";
    my $url = get_var("BUILDAH_BATS_URL", "https://github.com/containers/buildah/archive/refs/tags/v$buildah_version.tar.gz");
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

    my $errors = run_tests(rootless => 1, skip_tests => get_var('BUILDAH_BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir");

    $errors += run_tests(rootless => 0, skip_tests => get_var('BUILDAH_BATS_SKIP_ROOT', ''));

    die "Tests failed" if ($errors);
}

sub post_fail_hook {
    my ($self) = @_;
    bats_post_hook $test_dir;
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    bats_post_hook $test_dir;
    $self->SUPER::post_run_hook;
}

1;
