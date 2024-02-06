# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman integration
# Summary: Upstream podman integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use containers::utils qw(get_podman_version);
use utils qw(zypper_call script_retry ensure_serialdev_permissions);
use version_utils qw(get_os_release is_transactional is_sle is_sle_micro is_tumbleweed);
use transactional qw(trup_call check_reboot_changes);
use registration qw(add_suseconnect_product get_addon_fullname);
use containers::common;

my $test_dir = "/var/tmp";
my $podman_version = "";

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_podman_when_needed($host_distri);

    if (is_sle_micro) {
        my $sle_version = "";
        if (is_sle_micro('<5.3')) {
            $sle_version = "15.3";
        } elsif (is_sle_micro('<5.5')) {
            $sle_version = "15.4";
        } elsif (is_sle_micro('<6.0')) {
            $sle_version = "15.5";
        }
        trup_call "register -p PackageHub/$sle_version/" . get_required_var('ARCH');
        zypper_call "--gpg-auto-import-keys ref";
    } elsif (is_sle) {
        add_suseconnect_product(get_addon_fullname('phub'));
    }

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns bats catatonit jq make netavark netcat-openbsd openssl podman-remote python3-PyYAML socat sudo systemd-container);
    push @pkgs, qw(apache2-utils buildah criu go gpg2) unless is_sle_micro;
    push @pkgs, qw(skopeo) unless is_sle_micro('<5.5');
    if (is_transactional) {
        trup_call "-c pkg install -y @pkgs";
        check_reboot_changes;
    } else {
        zypper_call "in @pkgs";
    }

    # Workarounds for tests to work:
    # 1. Use netavark instead of cni
    # 2. Avoid default mounts for containers
    # 3. Switch to cgroups v2
    assert_script_run "podman system reset -f";
    if (is_transactional) {
        trup_call "run rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";
        check_reboot_changes;
    } else {
        script_run "rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";
    }
    switch_cgroup_version($self, 2);

    # Create user if not present
    if (script_run("grep $testapi::username /etc/passwd") != 0) {
        my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
        assert_script_run "useradd -m -G $serial_group $testapi::username";
        assert_script_run "echo '${testapi::username}:$testapi::password' | chpasswd";
        ensure_serialdev_permissions;
        select_console "user-console";
    } else {
        select_user_serial_terminal();
    }

    # Download podman sources
    my $test_dir = "/var/tmp";
    $podman_version = get_podman_version();
    assert_script_run "cd $test_dir";
    script_retry("curl -sL https://github.com/containers/podman/archive/refs/tags/v$podman_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd podman-$podman_version/";
    assert_script_run "sed -i 's/bats_opts=()/bats_opts=(--tap)/' hack/bats";
    assert_script_run "cp -r test/system test/system.orig";

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    #
    # user / local
    #

    my @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP') . " " . get_var('PODMAN_BATS_SKIP_USER_LOCAL', ''));
    foreach my $test (@skip_tests) {
        script_run "rm test/system/$test.bats";
    }

    my $log_file = "bats-user-local.tap";
    assert_script_run "echo $log_file .. > $log_file";
    script_run "env PODMAN=/usr/bin/podman QUADLET=$quadlet hack/bats --rootless | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf test/system";

    #
    # user / remote
    #

    assert_script_run "cp -r test/system.orig test/system";
    @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP') . " " . get_var('PODMAN_BATS_SKIP_USER_REMOTE', ''));
    foreach my $test (@skip_tests) {
        script_run "rm test/system/$test.bats";
    }

    $log_file = "bats-user-remote.tap";
    assert_script_run "echo $log_file .. > $log_file";
    background_script_run "podman system service --timeout=0";
    script_run "env PODMAN=/usr/bin/podman QUADLET=$quadlet hack/bats --rootless --remote | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf test/system";
    script_run 'kill %1';

    #
    # root / local
    #

    select_serial_terminal;
    assert_script_run("cd $test_dir/podman-$podman_version/");

    assert_script_run "cp -r test/system.orig test/system";
    @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP') . " " . get_var('PODMAN_BATS_SKIP_ROOT_LOCAL', ''));
    foreach my $test (@skip_tests) {
        script_run "rm test/system/$test.bats";
    }

    $log_file = "bats-root-local.tap";
    assert_script_run "echo $log_file .. > $log_file";
    script_run "env PODMAN=/usr/bin/podman QUADLET=$quadlet hack/bats --root | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf test/system";

    #
    # root / remote
    #

    assert_script_run "cp -r test/system.orig test/system";
    @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP') . " " . get_var('PODMAN_BATS_SKIP_ROOT_REMOTE', ''));
    foreach my $test (@skip_tests) {
        script_run "rm test/system/$test.bats";
    }

    $log_file = "bats-root-remote.tap";
    assert_script_run "echo $log_file .. > $log_file";
    background_script_run "podman system service --timeout=0";
    script_run "env PODMAN=/usr/bin/podman QUADLET=$quadlet hack/bats --root --remote | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);
    script_run 'kill %1';
}

sub cleanup() {
    script_run("rm -f $test_dir/podman-$podman_version/");
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
