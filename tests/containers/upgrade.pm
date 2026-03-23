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
use power_action_utils 'power_action';
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

sub upgrade_via_testrepos {
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
    my ($self, $run_args) = @_;
    # When a phase is not defined, we can use this module standalone
    # Otherwise this module can be parameterized to have a pre & a post phase
    my $phase = defined($run_args->{phase}) ? $run_args->{phase} : "standalone";

    select_serial_terminal;

    my @runtimes = ();
    if ($phase eq "standalone") {
        @runtimes = split(/,/, get_var("CONTAINER_RUNTIMES", "docker,podman"));
    } else {
        # The MicroOS image in the old2microosnext test doesn't come with docker pre-installed
        push @runtimes, "docker" if (script_run("which docker") == 0);
        push @runtimes, "podman" if (script_run("which podman") == 0);
    }

    if ($phase eq "standalone") {
        my @packages = ();
        push @packages, qw(docker docker-buildx docker-rootless-extras) if (grep { $_ eq "docker" } @runtimes);
        push @packages, qw(podman) if (grep { $_ eq "podman" } @runtimes);
        install_packages(@packages);
    }

    if ($phase ne "post") {
        my @packages = qw(jq);
        if (is_sle("<16")) {
            install_docker_compose;
        } else {
            push @packages, "docker-compose";
        }
        install_packages(@packages);

        for my $rootless (0, 1) {
            select_user_serial_terminal if $rootless;
            for my $runtime (@runtimes) {
                setup_containers $runtime, $rootless;
                $port++;
            }
        }

        assert_script_run "rpm -qa | sort > /var/tmp/before", timeout => 180;
        return if ($phase eq "pre");
    }

    if (get_var("TEST_REPOS")) {
        upgrade_via_testrepos;
        power_action('reboot', textmode => 1);
        $self->wait_boot();
    }

    assert_script_run "rpm -qa | sort > /var/tmp/after", timeout => 180;
    record_info "rpm diff", script_output "diff /var/tmp/before /var/tmp/after || true";

    $port = 8080;

    for my $rootless (0, 1) {
        select_user_serial_terminal if $rootless;
        for my $runtime (@runtimes) {
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
