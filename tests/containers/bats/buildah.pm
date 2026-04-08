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
use version;
use Utils::Architectures;
use containers::bats;

my $version = "";
my $docker_version = "";

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
        "add.bats::add https retry ca",
        # These may fail when github complains about 429 Too Many Requests
        # and we can't backport PR's 6146 & 6602 to fix this:
        "bud.bats::bud with --layers and --no-cache flags",
        "bud.bats::bud with --rm flag",
        "bud.bats::bud with no --layers comment",
        "images.bats::images all test",
        "rmi.bats::rmi with cached images",
    ) if (version->parse(numeric_version($version)) <= version->parse("1.39.5"));
    push @xfails, (
        "bud.bats::bud with --cgroup-parent",
    ) if (version->parse(numeric_version($version)) <= version->parse("1.39.5") && !$rootless);
    push @xfails, (
        "bud.bats::bud-git-context",
        "bud.bats::bud-git-context-subdirectory",
        "bud.bats::bud using gitrepo and branch",
        "run.bats::Check if containers run with correct open files/processes limits",
    ) if (version->parse(numeric_version($version)) < version->parse("1.39.5") && !$rootless);
    push @xfails, (
        "bud.bats::bud-multiple-platform-no-partial-manifest-list",
        # Fails with cgroups v1
        "namespaces.bats::use containers.conf namespace settings",
    ) if (is_sle("<15-SP6"));
    push @xfails, (
        "run.bats::run check /etc/resolv.conf",
    ) unless (is_aarch64 || is_x86_64);
    push @xfails, (
        # registry.access.redhat.com/ubi9-micro:latest may fail with:
        # Fatal glibc error: CPU lacks ISA 3.00 support (POWER9 or later required)
        "chroot.bats::chroot mount flags",
    ) if (is_ppc64le);

    my $ret = bats_tests($log_file, \%env, \@xfails, 6000);

    run_command "buildah prune -a -f";
    cleanup_podman;

    return ($ret);
}

# Get latest version of package in Tumbleweed
sub get_latest_version {
    my $package = shift;

    my $url = "https://mirrorcache.opensuse.org/rest/search/package_locations?ignore_file=json&ignore_path=%2Frepositories%2Fhome%3A&os=tumbleweed&official=1&package=$package";
    my $jq_script = qq(.data[] | select(.name == "$package" and (.file | test("^$package-[0-9]")) and (.path | startswith("/tumbleweed/repo/oss/"))) | .file | split("-")[1]);
    my $version = script_output qq(curl -sL "$url" | jq -Mr '$jq_script' | sort -Vr | head -1);
    return version->parse(numeric_version($version));
}

# Run conformance tests that compare the output of buildah against Docker's BuildKit
sub test_conformance {
    install_gotestsum;
    run_command 'cp /usr/bin/busybox-static tests/conformance/testdata/mount-targets/true';
    run_command 'docker rmi -f $(docker images -q) || true';
    run_timeout_command "gotestsum --junitfile conformance.xml --format standard-verbose -- ./tests/conformance/... &> conformance.txt", no_assert => 1, timeout => 1200;
    upload_logs "conformance.txt";
    die "Testsuite failed" if script_run("test -s conformance.xml");
    patch_junit "buildah", $version, "conformance.xml";
    parse_extra_log(XUnit => "conformance.xml");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(buildah docker git-daemon glibc-devel-static go1.26 libgpgme-devel libseccomp-devel make openssl podman selinux-tools);
    push @pkgs, "qemu-linux-user" if (is_tumbleweed || is_sle('>=15-SP6'));
    # Packages needed for conformance tests
    push @pkgs, "busybox-static docker-buildx libbtrfs-devel" unless is_sle;

    $self->setup_pkgs(@pkgs);

    record_info("buildah version", script_output("buildah --version"));
    record_info("buildah info", script_output("buildah info"));
    record_info("buildah package version", script_output("rpm -q buildah"));

    enable_docker;
    $docker_version = script_output "docker version --format '{{.Client.Version}}'";
    record_info("docker version", $docker_version);

    switch_to_user;

    record_info("buildah rootless", script_output("buildah info"));

    # Download buildah sources
    $version = script_output "buildah --version | awk '{ print \$3 }'";
    patch_sources "buildah", "v$version", "tests";

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

    # Run conformance tests only on demand, when new buildah & docker packages are published
    # You need to clone with BATS_IGNORE_USER=all BATS_IGNORE_ROOT=all RUN_TESTS=conformance
    test_conformance if (check_var("RUN_TESTS", "conformance") || (is_tumbleweed && is_x86_64 &&
            (get_latest_version("buildah") < version->parse(numeric_version($version)) ||
                get_latest_version("docker") < version->parse(numeric_version($docker_version)))));

    die "buildah tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
