# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-C team <qa-c@suse.de>

# Summary: Validate docker and podman runtime upgrades
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal;
use utils;
use version_utils;
use containers::bats;
use containers::common;

my $port = 8080;

sub validate {
    my $runtime = shift;

    assert_script_run "$runtime compose start";
    assert_script_run "$runtime compose logs";
    assert_script_run "$runtime compose ps";

    assert_script_run "$runtime container ls";
    assert_script_run "$runtime volume ls";
    assert_script_run "$runtime image ls";

    validate_script_output "curl -s http://127.0.0.1:$port", qr/Welcome to nginx/;
}

sub runtime_info {
    my $runtime = shift;

    record_info "$runtime compose version", script_output("$runtime compose version", proceed_on_failure => 1);
    record_info "$runtime version", script_output("$runtime version -f json | jq -Mr", proceed_on_failure => 1);
    record_info "$runtime info", script_output("$runtime info -f json | jq -Mr", proceed_on_failure => 1);
    if ($runtime eq "docker") {
        my $warnings = script_output("docker info -f '{{ range .Warnings }}{{ println . }}{{ end }}'", proceed_on_failure => 1);
        record_info "WARNINGS daemon", $warnings if $warnings;
        $warnings = script_output("docker info -f '{{ range .ClientInfo.Warnings }}{{ println . }}{{ end }}'", proceed_on_failure => 1);
        record_info "WARNINGS client", $warnings if $warnings;
    }
}

sub setup_containers {
    my ($runtime, $rootless) = @_;
    my $user = $rootless ? "--user" : "";

    if ($runtime eq "docker") {
        assert_script_run "dockerd-rootless-setuptool.sh install" if $rootless;
        systemctl "$user start docker.service";
    } else {
        systemctl "$user start podman.socket";
    }

    runtime_info $runtime;

    assert_script_run "curl -O " . data_url("containers/docker-compose.yml");
    assert_script_run "curl -O " . data_url("containers/haproxy.cfg");
    assert_script_run "sed -i 's/8080/$port/g' docker-compose.yml";

    assert_script_run "$runtime compose pull", 600;
    assert_script_run "$runtime compose up -d", 120;
    wait_still_screen stilltime => 15, timeout => 180;

    validate $runtime;

    assert_script_run "$runtime compose stop", 180;
}

sub upgrade {
    select_serial_terminal;

    foreach my $repo (split /\s+/, get_var("TEST_REPOS", "")) {
        zypper_call "addrepo -f $repo";
    }

    # Needed to avoid this error on SLES 15-SP7:
    #   File /usr/share/containers/mounts.conf from install of
    #   libcontainers-common-20260112-bp157.3.1.noarch (Virtualization:containers (15.7))
    #   conflicts with file from package libcontainers-sles-mounts-20240408-150600.1.1.noarch (@System)
    my $replace = is_sle("<16") ? "--replacefiles" : "";
    zypper_call "--gpg-auto-import-keys --no-gpg-checks up --allow-vendor-change --details $replace", timeout => 600;
}

sub cleanup {
    my ($runtime, $rootless) = @_;
    my $user = $rootless ? "--user" : "";

    script_run "$runtime compose down", timeout => 180;
    script_run "$runtime rmi \$($runtime images -aq)", timeout => 180;

    if ($runtime eq "docker") {
        script_run "dockerd-rootless-setuptool.sh uninstall" if $rootless;
    } else {
        systemctl "$user stop podman.socket";
    }
}

sub run {
    my $self = shift;

    select_serial_terminal;

    my @pkgs = qw(docker docker-buildx docker-rootless-extras jq podman);
    push @pkgs, qw(docker-compose) unless is_sle("<16");
    install_packages(@pkgs);

    install_docker_compose if is_sle("<16");

    for my $rootless (0, 1) {
        select_user_serial_terminal if $rootless;
        for my $runtime ("docker", "podman") {
            setup_containers $runtime, $rootless;
            $port++;
        }
    }

    assert_script_run "rpm -qa | sort > /tmp/before", timeout => 180;
    upgrade;
    assert_script_run "rpm -qa | sort > /tmp/after", timeout => 180;
    record_info "rpm diff", script_output "diff /tmp/before /tmp/after || true";

    $port = 8080;

    for my $rootless (0, 1) {
        select_user_serial_terminal if $rootless;
        for my $runtime ("docker", "podman") {
            my $user = $rootless ? "--user" : "";
            if ($runtime eq "docker") {
                systemctl "$user restart docker.service";
            } else {
                systemctl "$user restart podman.socket";
            }
            runtime_info $runtime;
            validate $runtime;
            cleanup $runtime, $rootless;
            $port++;
        }
    }
}

1;
