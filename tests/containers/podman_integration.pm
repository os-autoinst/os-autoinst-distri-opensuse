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
use utils qw(zypper_call script_retry);
use version_utils qw(get_os_release);
use containers::common;

sub run {
    select_serial_terminal;
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_podman_when_needed($host_distri);

    # Install tests dependencies
    my @pkgs = qw(apache2-utils bats buildah criu go gpg2 jq make netcat-openbsd openssl podman-remote python3-PyYAML skopeo socat sudo systemd-container);
    zypper_call "in @pkgs";

    assert_script_run "cd /home/$testapi::username";
    my $podman_version = get_podman_version();
    script_retry("curl -sL https://github.com/containers/podman/archive/refs/tags/v$podman_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd podman-$podman_version/";
    # The user must be able to create a log file too
    assert_script_run "chmod 1777 .";

    assert_script_run "sed -i 's/bats_opts=()/bats_opts=(--tap)/' hack/bats";

    my @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP'));
    foreach my $test (@skip_tests) {
        assert_script_run "rm test/system/$test.bats";
    }

    # root / local
    my $log_file = "bats-root-local.tap";
    assert_script_run "echo $log_file .. > $log_file";
    script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --root | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);

    # root / remote
    $log_file = "bats-root-remote.tap";
    assert_script_run "echo $log_file .. > $log_file";
    background_script_run "podman system service --timeout=0";
    script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --root --remote | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);
    script_run 'kill %1';

    select_user_serial_terminal();

    # user / local
    $log_file = "bats-user-local.tap";
    assert_script_run "echo $log_file .. > $log_file";
    script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --rootless | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);

    # user /remote
    $log_file = "bats-user-remote.tap";
    assert_script_run "echo $log_file .. > $log_file";
    background_script_run "podman system service --timeout=0";
    script_run "env PODMAN=/usr/bin/podman QUADLET=/usr/libexec/podman/quadlet hack/bats --rootless --remote | tee -a $log_file", 2600;
    parse_extra_log(TAP => $log_file);
    script_run 'kill %1';
}

1;
