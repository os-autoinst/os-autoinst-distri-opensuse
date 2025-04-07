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
use containers::utils qw(get_podman_version);
use utils qw(script_retry);
use version_utils qw(is_sle is_tumbleweed);
use containers::common;
use Utils::Architectures qw(is_x86_64 is_aarch64);
use containers::bats;

my $test_dir = "/var/tmp/podman-tests";
my $oci_runtime = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $remote, $skip_tests) = ($params{rootless}, $params{remote}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $log_file = "bats-" . ($rootless ? "user" : "root") . "-" . ($remote ? "remote" : "local") . ".tap";
    my $args = ($rootless ? "--rootless" : "--root");
    $args .= " --remote" if ($remote);

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    my $tmp_dir = script_output "mktemp -d -p /var/tmp test.XXXXXX";
    selinux_hack $tmp_dir;

    my %_env = (
        BATS_TMPDIR => $tmp_dir,
        PODMAN => "/usr/bin/podman",
        QUADLET => $quadlet,
        PATH => '/usr/local/bin:$PATH:/usr/sbin:/sbin',
    );
    my $env = join " ", map { "$_=$_env{$_}" } sort keys %_env;

    assert_script_run "echo $log_file .. > $log_file";
    background_script_run "podman system service --timeout=0" if ($remote);

    my @tests;
    foreach my $test (split(/\s+/, get_var("PODMAN_BATS_TESTS", ""))) {
        $test .= ".bats" unless $test =~ /\.bats$/;
        push @tests, "test/system/$test";
    }
    my $tests = join(" ", @tests);

    my $ret = script_run "env $env hack/bats $args $tests | tee -a $log_file", 8000;
    script_run 'kill %1; kill -9 %1' if ($remote);

    unless (@tests) {
        my @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP') . " " . $skip_tests);
        # Unconditionally ignore these flaky subtests
        my @must_skip = (
            # this test depends on the openQA worker's scheduler
            "180-blkio",
            # this test will fail if there's not "enough" free space
            "320-system-df",
        );
        push @skip_tests, @must_skip;
        patch_logfile($log_file, @skip_tests);
    }

    parse_extra_log(TAP => $log_file);

    script_run 'podman rm -vf $(podman ps -aq --external)';
    assert_script_run "podman system reset -f";
    script_run "rm -rf $tmp_dir";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns catatonit git-core gpg2 iptables jq make netavark openssl podman python3-PyYAML sudo systemd-container);
    push @pkgs, qw(apache2-utils buildah glibc-devel-static go libcriu2 libgpgme-devel libseccomp-devel podman-remote socat skopeo);
    # passt requires podman 5.0
    push @pkgs, qw(criu passt) if (is_tumbleweed);
    # Needed for podman machine
    if (is_x86_64) {
        push @pkgs, "qemu-x86";
    } elsif (is_aarch64) {
        push @pkgs, "qemu-arm";
    }
    install_packages(@pkgs);
    install_ncat;

    $oci_runtime = install_oci_runtime;

    $self->bats_setup;

    assert_script_run "podman system reset -f";
    assert_script_run "modprobe ip6_tables";

    record_info("podman version", script_output("podman version"));
    record_info("podman info", script_output("podman info"));
    record_info("podman package version", script_output("rpm -q podman"));

    switch_to_user;

    record_info("podman rootless", script_output("podman info"));

    # Download podman sources
    my $podman_version = get_podman_version();
    my $url = get_var("PODMAN_BATS_URL", "https://github.com/containers/podman/archive/refs/tags/v$podman_version.tar.gz");
    assert_script_run "mkdir -p $test_dir";
    assert_script_run("cd $test_dir");
    script_retry("curl -sL $url | tar -zxf - --strip-components 1", retry => 5, delay => 60, timeout => 300);

    # Patch tests
    assert_script_run "sed -i 's/bats_opts=()/bats_opts=(--tap)/' hack/bats";
    assert_script_run "sed -i 's/^PODMAN_RUNTIME=/&$oci_runtime/' test/system/helpers.bash";
    assert_script_run "rm -f contrib/systemd/system/podman-kube@.service.in";

    # Compile helpers used by the tests
    script_run "make podman-testing", timeout => 600;

    # user / local
    my $errors = run_tests(rootless => 1, remote => 0, skip_tests => get_var('PODMAN_BATS_SKIP_USER_LOCAL', ''));

    # user / remote
    $errors += run_tests(rootless => 1, remote => 1, skip_tests => get_var('PODMAN_BATS_SKIP_USER_REMOTE', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir");

    # root / local
    $errors += run_tests(rootless => 0, remote => 0, skip_tests => get_var('PODMAN_BATS_SKIP_ROOT_LOCAL', ''));

    # root / remote
    $errors += run_tests(rootless => 0, remote => 1, skip_tests => get_var('PODMAN_BATS_SKIP_ROOT_REMOTE', ''));

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
