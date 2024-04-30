# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman integration
# Summary: Upstream podman integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::utils qw(get_podman_version);
use utils qw(script_retry);
use version_utils qw(is_sle is_sle_micro is_tumbleweed is_microos is_leap is_leap_micro);
use containers::common;
use Utils::Architectures qw(is_x86_64 is_aarch64);
use Utils::Systemd qw(systemctl);
use containers::bats qw(install_bats add_packagehub remove_mounts_conf switch_to_user);

my $test_dir = "/var/tmp";
my $podman_version = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $remote, $skip_tests) = ($params{rootless}, $params{remote}, $params{skip_tests});

    my $log_file = "bats-" . ($rootless ? "user" : "root") . "-" . ($remote ? "remote" : "local") . ".tap";
    my $args = ($rootless ? "--rootless" : "--root");
    $args .= " --remote" if ($remote);

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    assert_script_run "cp -r test/system.orig test/system";
    my @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP') . " " . $skip_tests);
    script_run "rm test/system/$_.bats" foreach (@skip_tests);

    assert_script_run "echo $log_file .. > $log_file";
    background_script_run "podman system service --timeout=0" if ($remote);
    script_run "env PODMAN=/usr/bin/podman QUADLET=$quadlet hack/bats $args | tee -a $log_file", 3600;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf test/system";
    script_run 'kill %1' if ($remote);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    add_packagehub;
    install_bats;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns catatonit jq make netavark netcat-openbsd openssl podman python3-PyYAML socat sudo systemd-container);
    push @pkgs, qw(apache2-utils buildah criu go gpg2) unless is_sle_micro;
    push @pkgs, qw(podman-remote skopeo) unless is_sle_micro('<5.5');
    # NOTE: passt should be pulled in as a dependency on podman 5.0+
    push @pkgs, qw(passt) if (is_tumbleweed || is_microos || is_sle_micro('>=6.0') || is_leap_micro('>=6.0'));
    # Needed for podman machine
    if (is_x86_64) {
        push @pkgs, "qemu-x86";
    } elsif (is_aarch64) {
        push @pkgs, "qemu-arm";
    }
    install_packages(@pkgs);

    # Workarounds for tests to work:
    # 1. Use netavark instead of cni
    # 2. Avoid default mounts for containers
    # 3. Switch to cgroups v2

    # Required modifications to make cgroups v2 work on SLES<15-SP6.
    # See https://susedoc.github.io/doc-sle/main/html/SLES-tuning/cha-tuning-cgroups.html#sec-cgroups-user-sessions
    if (is_sle('<15-SP6') || is_leap('<15.6')) {
        assert_script_run "mkdir /etc/systemd/system/user@.service.d/";
        assert_script_run 'echo -e "[Service]\nDelegate=pids memory" > /etc/systemd/system/user@.service.d/60-delegate.conf';
        systemctl "daemon-reload";
        systemctl "--user daemon-reexec";
    }

    assert_script_run "podman system reset -f";

    remove_mounts_conf;

    switch_cgroup_version($self, 2);

    switch_to_user;

    # Download podman sources
    my $test_dir = "/var/tmp";
    $podman_version = get_podman_version();
    assert_script_run "cd $test_dir";
    script_retry("curl -sL https://github.com/containers/podman/archive/refs/tags/v$podman_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd podman-$podman_version/";
    assert_script_run "sed -i 's/bats_opts=()/bats_opts=(--tap)/' hack/bats";
    assert_script_run "cp -r test/system test/system.orig";

    # user / local
    run_tests(rootless => 1, remote => 0, skip_tests => get_var('PODMAN_BATS_SKIP_USER_LOCAL', ''));

    # user / remote
    run_tests(rootless => 1, remote => 1, skip_tests => get_var('PODMAN_BATS_SKIP_USER_REMOTE', '')) unless (is_sle_micro('<5.5'));

    select_serial_terminal;
    assert_script_run("cd $test_dir/podman-$podman_version/");

    # root / local
    run_tests(rootless => 0, remote => 0, skip_tests => get_var('PODMAN_BATS_SKIP_ROOT_LOCAL', ''));

    # root / remote
    run_tests(rootless => 0, remote => 1, skip_tests => get_var('PODMAN_BATS_SKIP_ROOT_REMOTE', '')) unless (is_sle_micro('<5.5'));
}

sub cleanup() {
    script_run("rm -rf $test_dir/podman-$podman_version/");
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
