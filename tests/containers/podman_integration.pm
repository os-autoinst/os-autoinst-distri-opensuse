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

sub run {
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
    my @pkgs = qw(bats jq make netcat-openbsd openssl python3-PyYAML socat sudo systemd-container);
    push @pkgs, qw(apache2-utils buildah criu go gpg2 podman-remote skopeo) unless is_sle_micro;
    if (is_transactional) {
        trup_call "-c pkg install -y @pkgs";
        check_reboot_changes;
    } else {
        zypper_call "in @pkgs";
    }

    if (script_run("grep $testapi::username /etc/passwd") != 0) {
        my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
        assert_script_run "useradd -m -G $serial_group $testapi::username";
        assert_script_run "echo '${testapi::username}:$testapi::password' | chpasswd";
    }

    my $test_dir = (script_run("grep $testapi::username /etc/passwd") == 0) ? "/home/$testapi::username" : "/root";
    assert_script_run "cd $test_dir";

    my $podman_version = get_podman_version();
    script_retry("curl -sL https://github.com/containers/podman/archive/refs/tags/v$podman_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd podman-$podman_version/";
    # The user must be able to create a log file too
    assert_script_run "chmod 1777 .";

    assert_script_run "sed -i 's/bats_opts=()/bats_opts=(--tap)/' hack/bats";

    my @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP'));
    push @skip_tests, "252-quadlet" unless is_tumbleweed;
    foreach my $test (@skip_tests) {
        assert_script_run "rm test/system/$test.bats";
    }

    # root / local
    my $log_file = "bats-root-local.tap";
    assert_script_run "echo $log_file .. > $log_file";
    script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --root | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);

    # root / remote
    unless (is_sle_micro) {
        $log_file = "bats-root-remote.tap";
        assert_script_run "echo $log_file .. > $log_file";
        background_script_run "podman system service --timeout=0";
        script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --root --remote | tee -a $log_file", 2600;
        parse_extra_log(TAP => $log_file);
        script_run 'kill %1';
    }

    if (is_sle_micro) {
        ensure_serialdev_permissions;
        select_console "user-console";
    } else {
        select_user_serial_terminal();
    }

    # user / local
    $log_file = "bats-user-local.tap";
    assert_script_run "echo $log_file .. > $log_file";
    script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --rootless | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);

    # user /remote
    unless (is_sle_micro) {
        $log_file = "bats-user-remote.tap";
        assert_script_run "echo $log_file .. > $log_file";
        background_script_run "podman system service --timeout=0";
        script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --rootless --remote | tee -a $log_file", 2600;
        parse_extra_log(TAP => $log_file);
        script_run 'kill %1';
    }
}

1;
