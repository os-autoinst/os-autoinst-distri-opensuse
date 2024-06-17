# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: buildah
# Summary: Upstream buildah integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use containers::bats qw(install_bats patch_logfile switch_to_user delegate_controllers enable_modules remove_mounts_conf);
use version_utils qw(is_sle is_tumbleweed);

my $test_dir = "/var/tmp";
my $buildah_version = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $log_file = "buildah-" . ($rootless ? "user" : "root") . ".tap";

    my @skip_tests = split(/\s+/, get_var('BUILDAH_BATS_SKIP', '') . " " . $skip_tests);

    assert_script_run "echo $log_file .. > $log_file";
    script_run "BATS_TMPDIR=/var/tmp TMPDIR=/var/tmp BUILDAH_BINARY=/usr/bin/buildah STORAGE_DRIVER=overlay bats --tap tests | tee -a $log_file", 4200;
    patch_logfile($log_file, @skip_tests);
    parse_extra_log(TAP => $log_file);

    assert_script_run "buildah prune -a -f";
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(buildah docker git-core glibc-devel-static go jq libgpgme-devel libseccomp-devel make openssl podman runc selinux-tools);
    push @pkgs, qw(crun) if is_tumbleweed;
    install_packages(@pkgs);

    delegate_controllers;

    remove_mounts_conf;

    switch_cgroup_version($self, 2);

    record_info("buildah version", script_output("buildah --version"));
    record_info("buildah info", script_output("buildah info"));

    switch_to_user;

    my $test_dir = "/var/tmp";
    assert_script_run "cd $test_dir";

    # Download buildah sources
    $buildah_version = script_output "buildah --version | awk '{ print \$3 }'";
    script_retry("curl -sL https://github.com/containers/buildah/archive/refs/tags/v$buildah_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd $test_dir/buildah-$buildah_version/";

    # Compile helpers used by the tests
    assert_script_run "make bin/imgtype bin/copy bin/tutorial", timeout => 600;

    run_tests(rootless => 1, skip_tests => get_var('BUILDAH_BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir/buildah-$buildah_version/");

    run_tests(rootless => 0, skip_tests => get_var('BUILDAH_BATS_SKIP_ROOT', ''));
}

sub cleanup() {
    assert_script_run "cd ~";
    script_run("rm -rf $test_dir/buildah-$buildah_version/");
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
