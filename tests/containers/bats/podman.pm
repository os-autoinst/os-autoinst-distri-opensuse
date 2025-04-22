# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman integration
# Summary: Upstream podman integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use version_utils qw(is_tumbleweed);
use containers::common;
use Utils::Architectures qw(is_x86_64 is_aarch64);
use containers::bats;

my $test_dir = "/var/tmp/podman-tests";
my $oci_runtime = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $remote, $skip_tests) = ($params{rootless}, $params{remote}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    my %env = (
        PODMAN => "/usr/bin/podman",
        QUADLET => $quadlet,
    );

    my $log_file = "bats-" . ($rootless ? "user" : "root") . "-" . ($remote ? "remote" : "local") . ".tap";

    background_script_run "podman system service --timeout=0" if ($remote);

    my $ret = bats_tests($log_file, \%env, $skip_tests);

    script_run 'kill %1; kill -9 %1' if ($remote);

    script_run 'podman rm -vf $(podman ps -aq --external)';
    assert_script_run "podman system reset -f";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(aardvark-dns apache2-utils buildah catatonit git-core glibc-devel-static go gpg2 jq libcriu2 libgpgme-devel
      libseccomp-devel make netavark openssl podman podman-remote python3-PyYAML skopeo socat sudo systemd-container);
    push @pkgs, qw(criu) if is_tumbleweed;
    # Needed for podman machine
    if (is_x86_64) {
        push @pkgs, "qemu-x86";
    } elsif (is_aarch64) {
        push @pkgs, "qemu-arm";
    }

    $self->bats_setup(@pkgs);

    install_ncat;

    assert_script_run "podman system reset -f";
    assert_script_run "modprobe ip6_tables";

    record_info("podman version", script_output("podman version"));
    record_info("podman info", script_output("podman info"));
    record_info("podman package version", script_output("rpm -q podman"));

    switch_to_user;

    record_info("podman rootless", script_output("podman info"));

    # Download podman sources
    my $podman_version = script_output "podman --version | awk '{ print \$3 }'";
    my $url = get_var("BATS_URL", "https://github.com/containers/podman/archive/refs/tags/v$podman_version.tar.gz");
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "cd $test_dir";
    script_retry("curl -sL $url | tar -zxf - --strip-components 1", retry => 5, delay => 60, timeout => 300);

    $oci_runtime = get_var("OCI_RUNTIME", script_output("podman info --format '{{ .Host.OCIRuntime.Name }}'"));

    # Patch tests
    assert_script_run "sed -i 's/bats_opts=()/bats_opts=(--tap)/' hack/bats";
    assert_script_run "sed -i 's/^PODMAN_RUNTIME=/&$oci_runtime/' test/system/helpers.bash";
    assert_script_run "rm -f contrib/systemd/system/podman-kube@.service.in";
    # This test is flaky and will fail if system is "full"
    assert_script_run "rm -f test/system/320-system-df.bats";

    # Compile helpers used by the tests
    script_run "make podman-testing", timeout => 600;

    # user / local
    my $errors = run_tests(rootless => 1, remote => 0, skip_tests => get_var('BATS_SKIP_USER_LOCAL', ''));

    # user / remote
    $errors += run_tests(rootless => 1, remote => 1, skip_tests => get_var('BATS_SKIP_USER_REMOTE', ''));

    select_serial_terminal;
    assert_script_run "cd $test_dir";

    # root / local
    $errors += run_tests(rootless => 0, remote => 0, skip_tests => get_var('BATS_SKIP_ROOT_LOCAL', ''));

    # root / remote
    $errors += run_tests(rootless => 0, remote => 1, skip_tests => get_var('BATS_SKIP_ROOT_REMOTE', ''));

    die "podman tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook $test_dir;
}

sub post_run_hook {
    bats_post_hook $test_dir;
}

1;
