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
use version_utils;
use containers::bats;

sub run_tests {
    my %params = @_;
    my $rootless = $params{rootless};

    my $storage_driver = $rootless ? "vfs" : script_output("buildah info --format '{{ .store.GraphDriverName }}'");
    record_info("storage driver", $storage_driver);

    my $oci_runtime = get_var('OCI_RUNTIME', script_output("buildah info --format '{{ .host.OCIRuntime }}'"));

    my %env = (
        BUILDAH_BINARY => "/usr/bin/buildah",
        BUILDAH_RUNTIME => $oci_runtime,
        CI_DESIRED_RUNTIME => $oci_runtime,
        STORAGE_DRIVER => $storage_driver,
    );

    my $log_file = "buildah-" . ($rootless ? "user" : "root");

    my @xfails = ();
    push @xfails, (
        "add.bats::add https retry ca"
    ) if (is_sle(">16"));
    push @xfails, (
        "bud.bats::bud with --cgroup-parent",
    ) if (is_sle && !$rootless);
    push @xfails, (
        "bud.bats::bud-git-context",
        "bud.bats::bud-git-context-subdirectory",
        "bud.bats::bud using gitrepo and branch",
        "run.bats::Check if containers run with correct open files/processes limits",
    ) if (is_sle("<16") && !$rootless);
    push @xfails, (
        "bud.bats::bud-multiple-platform-no-partial-manifest-list",
    ) if (is_sle("<15-SP6"));

    my $ret = bats_tests($log_file, \%env, \@xfails, 5000);

    run_command "buildah prune -a -f";
    cleanup_podman;

    return ($ret);
}

sub enable_docker {
    run_command 'systemctl enable --now docker';
    run_command "usermod -aG docker $testapi::username";

    # Needed to avoid:
    # WARNING: COMMAND_FAILED: '/sbin/iptables -t nat -F DOCKER' failed: iptables: No chain/target/match by that name.
    # See https://bugzilla.suse.com/show_bug.cgi?id=1196801
    run_command 'systemctl restart firewalld';

    # Running podman as root with docker installed may be problematic as netavark uses nftables
    # while docker still uses iptables.
    # Use workaround suggested in:
    # - https://fedoraproject.org/wiki/Changes/NetavarkNftablesDefault#Known_Issue_with_docker
    # - https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-on-a-router
    if (script_run("iptables -L -v | grep -q DOCKER") == 0) {
        run_command "iptables -I DOCKER-USER -j ACCEPT";
        run_command "ip6tables -I DOCKER-USER -j ACCEPT";
    }

    record_info("docker info", script_output("docker info -f json | jq -Mr"));
    my $warnings = script_output("docker info -f '{{ range .Warnings }}{{ println . }}{{ end }}'");
    record_info("WARNINGS daemon", $warnings) if $warnings;
    $warnings = script_output("docker info -f '{{ range .ClientInfo.Warnings }}{{ println . }}{{ end }}'");
    record_info("WARNINGS client", $warnings) if $warnings;
    record_info("docker version", script_output("docker version -f json | jq -Mr"));
}

# Run conformance tests that compare the output of buildah against Docker's BuildKit
sub test_conformance {
    install_gotestsum;
    run_command 'cp /usr/bin/busybox-static tests/conformance/testdata/mount-targets/true';
    run_command 'docker rmi -f $(docker images -q) || true';
    run_command 'gotestsum --junitfile conformance.xml --format standard-verbose -- ./tests/conformance/... |& tee conformance.txt', timeout => 1200;
    my $version = script_output "buildah version --json | jq -Mr .version";
    patch_junit "buildah", $version, "conformance.xml";
    parse_extra_log(XUnit => "conformance.xml");
    upload_logs("conformance.txt");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(buildah docker git-daemon glibc-devel-static go1.24 libgpgme-devel libseccomp-devel make openssl podman selinux-tools);
    push @pkgs, "qemu-linux-user" if (is_tumbleweed || is_sle('>=15-SP6'));
    # Packages needed for conformance tests
    push @pkgs, "busybox-static docker-buildx libbtrfs-devel" unless is_sle;

    $self->setup_pkgs(@pkgs);

    record_info("buildah version", script_output("buildah --version"));
    record_info("buildah info", script_output("buildah info"));
    record_info("buildah package version", script_output("rpm -q buildah"));

    enable_docker;

    switch_to_user;

    record_info("buildah rootless", script_output("buildah info"));

    # Download buildah sources
    my $buildah_version = script_output "buildah --version | awk '{ print \$3 }'";
    patch_sources "buildah", "v$buildah_version", "tests";

    # Patch mkdir to always use -p
    run_command "sed -i 's/ mkdir /& -p /' tests/*.bats tests/helpers.bash";

    # Compile helpers used by the tests
    my $helpers = script_output 'echo $(grep ^all: Makefile | grep -o "bin/[a-z]*" | grep -v bin/buildah)';
    record_info("helpers", $helpers);
    run_command "make $helpers", timeout => 600;

    my $errors = 0;
    $errors += run_tests(rootless => 1) unless check_var('BATS_IGNORE_USER', 'all');

    switch_to_root;

    $errors += run_tests(rootless => 0) unless check_var('BATS_IGNORE_ROOT', 'all');

    test_conformance unless is_sle;

    die "buildah tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
