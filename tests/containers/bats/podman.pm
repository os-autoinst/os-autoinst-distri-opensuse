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
use version_utils qw(is_sle is_tumbleweed);
use Utils::Architectures;
use containers::bats;

my $oci_runtime = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $remote, $skip_tests) = ($params{rootless}, $params{remote}, $params{skip_tests});

    return 0 if check_var($skip_tests, "all");

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    my %env = (
        PODMAN_ROOTLESS_USER => $testapi::username,
        PODMAN => "/usr/bin/podman",
        QUADLET => $quadlet,
    );

    my $log_file = "bats-" . ($rootless ? "user" : "root") . "-" . ($remote ? "remote" : "local") . ".tap.txt";

    run_command "podman system service --timeout=0 &" if ($remote);

    my $ret = bats_tests($log_file, \%env, $skip_tests, 5000);

    run_command 'kill %1; kill -9 %1 || true' if ($remote);

    run_command 'podman rm -vf $(podman ps -aq --external) || true';
    run_command "podman system reset -f";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(aardvark-dns apache2-utils buildah catatonit glibc-devel-static go1.24 gpg2 jq libgpgme-devel
      libseccomp-devel make netavark openssl podman podman-remote python3-PyYAML skopeo socat sudo systemd-container xfsprogs);
    push @pkgs, qw(criu libcriu2) if is_tumbleweed;
    push @pkgs, qw(netcat-openbsd) if is_sle("<16");
    # Needed for podman machine
    if (is_x86_64) {
        push @pkgs, "qemu-x86";
    } elsif (is_aarch64) {
        push @pkgs, "qemu-arm";
    }

    $self->bats_setup(@pkgs);

    run_command "podman system reset -f";
    run_command "modprobe ip6_tables";
    run_command "modprobe null_blk nr_devices=1 || true";

    record_info("podman version", script_output("podman version"));
    record_info("podman info", script_output("podman info"));
    record_info("podman package version", script_output("rpm -q podman"));

    switch_to_user;

    record_info("podman rootless", script_output("podman info"));

    # Download podman sources
    my $podman_version = script_output "podman --version | awk '{ print \$3 }'";
    bats_sources $podman_version;

    $oci_runtime = get_var("OCI_RUNTIME", script_output("podman info --format '{{ .Host.OCIRuntime.Name }}'"));

    # Patch tests
    run_command "sed -i 's/^PODMAN_RUNTIME=/&$oci_runtime/' test/system/helpers.bash";
    run_command "rm -f contrib/systemd/system/podman-kube@.service.in";
    unless (get_var("BATS_TESTS")) {
        # This test fails on systems with GNU tar 1.35 due to
        # https://bugzilla.suse.com/show_bug.cgi?id=1246607
        run_command "rm -f test/system/125-import.bats" if (!is_x86_64 && (is_tumbleweed || is_sle('>=16.0')));
        # This test is flaky on architectures other than x86_64
        run_command "rm -f test/system/180-blkio.bats" unless is_x86_64;
        # This test is flaky on ppc64le & s390x
        run_command "rm -f test/system/220-healthcheck.bats" if (is_ppc64le || is_s390x);
        # This test is flaky and will fail if system is "full"
        run_command "rm -f test/system/320-system-df.bats";
        # This tests needs criu, available only on Tumbleweed
        run_command "rm -f test/system/520-checkpoint.bats" unless is_tumbleweed;
    }

    # Compile helpers used by the tests
    run_command "make podman-testing || true", timeout => 600;

    my $errors = 0;
    unless (check_var("BATS_IGNORE_USER", "all")) {
        # user / local
        $errors += run_tests(rootless => 1, remote => 0, skip_tests => 'BATS_IGNORE_USER_LOCAL');

        # user / remote
        $errors += run_tests(rootless => 1, remote => 1, skip_tests => 'BATS_IGNORE_USER_REMOTE');
    }

    switch_to_root;

    unless (check_var("BATS_IGNORE_ROOT", "all")) {
        # root / local
        $errors += run_tests(rootless => 0, remote => 0, skip_tests => 'BATS_IGNORE_ROOT_LOCAL');

        # root / remote
        $errors += run_tests(rootless => 0, remote => 1, skip_tests => 'BATS_IGNORE_ROOT_REMOTE');
    }

    die "podman tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
