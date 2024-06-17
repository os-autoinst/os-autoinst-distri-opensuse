# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: skopeo
# Summary: Upstream skopeo integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use Utils::Architectures qw(is_x86_64);
use containers::bats qw(install_bats patch_logfile remove_mounts_conf switch_to_user enable_modules);
use version_utils qw(is_sle);

my $test_dir = "/var/tmp";
my $skopeo_version = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $log_file = "skopeo-" . ($rootless ? "user" : "root") . ".tap";

    my @skip_tests = split(/\s+/, get_var('SKOPEO_BATS_SKIP', '') . " " . $skip_tests);

    # Upstream script gets GOARCH by calling `go env GOARCH`.  Drop go dependency for this only use of go
    my $goarch = script_output "podman version -f '{{.OsArch}}' | cut -d/ -f2";
    assert_script_run "sed -i 's/arch=.*/arch=$goarch/' systemtest/010-inspect.bats";

    # Default quay.io/libpod/registry:2 image used by the test only has amd64 image
    my $registry = is_x86_64 ? "" : "docker.io/library/registry:2";

    assert_script_run "echo $log_file .. > $log_file";
    script_run "BATS_TMPDIR=/var/tmp SKOPEO_BINARY=/usr/bin/skopeo SKOPEO_TEST_REGISTRY_FQIN=$registry bats --tap systemtest | tee -a $log_file", 1200;
    patch_logfile($log_file, @skip_tests);
    parse_extra_log(TAP => $log_file);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(jq openssl podman python3-passlib skopeo);
    install_packages(@pkgs);

    assert_script_run "curl -o /usr/local/bin/htpasswd " . data_url("containers/htpasswd");
    assert_script_run "chmod +x /usr/local/bin/htpasswd";

    record_info("skopeo version", script_output("skopeo --version"));

    remove_mounts_conf;

    switch_to_user;

    my $test_dir = "/var/tmp";
    assert_script_run "cd $test_dir";

    # Download skopeo sources
    $skopeo_version = script_output "skopeo --version  | awk '{ print \$3 }'";
    script_retry("curl -sL https://github.com/containers/skopeo/archive/refs/tags/v$skopeo_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd $test_dir/skopeo-$skopeo_version/";

    run_tests(rootless => 1, skip_tests => get_var('SKOPEO_BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir/skopeo-$skopeo_version/");

    run_tests(rootless => 0, skip_tests => get_var('SKOPEO_BATS_SKIP_ROOT', ''));
}

sub cleanup() {
    assert_script_run "cd ~";
    script_run("rm -rf $test_dir/skopeo-$skopeo_version/");
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
