# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate docker and podman network interoperability
# - validate if podman and docker networking works together
# - check if firewalld doesn't break either
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(containers::basetest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(check_os_release get_os_release is_sle is_sle_micro is_transactional);
use transactional qw(check_reboot_changes);

my $test_image = "registry.opensuse.org/opensuse/nginx";
my $test_egress_cmd = "curl https://opensuse.org/ -vso/dev/null";

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;

    # Initialize podman
    $self->containers_factory('podman');

    # Required, otherwise any subsequent outgoing podman connections fail
    # https://progress.opensuse.org/issues/173362
    assert_script_run("podman run --rm $test_image $test_egress_cmd");

    # Initialize docker
    $self->containers_factory('docker');

    # Stop docker daemon and start firewalld
    systemctl("disable --now docker");
    systemctl("enable --now firewalld");

    systemctl("is-active docker", expect_false => 1);
    systemctl("is-active firewalld");

    record_info('Firewalld Zones', script_output("firewall-cmd --zone=public --list-all && firewall-cmd --get-zones | grep -i docker && firewall-cmd --zone=docker --list-all"));

    script_retry("podman pull $test_image", retry => 3, delay => 60, timeout => 180);

    # Start nginx in podman and validate initial ingress connectivity
    assert_script_run("podman run -d --name nginx --rm $test_image");
    my $nginx_podman_ip = script_output("podman container inspect nginx -f '{{ .NetworkSettings.IPAddress }}'");
    script_retry("curl $nginx_podman_ip -svo/dev/null", retry => 3, delay => 6);

    # Validate initial podman egress connectivity
    assert_script_run("podman run --rm $test_image $test_egress_cmd");

    # Start docker and validate podman connectivity
    systemctl("start docker");
    systemctl("is-active docker");
    systemctl("is-active firewalld");
    if (script_run("curl $nginx_podman_ip -svo/dev/null") != 0) { bsc_1213811("ingress podman connection failed"); }
    if (script_run("podman run --rm $test_image $test_egress_cmd") != 0) { bsc_1213811("egress podman connection failed"); }

    # Prepare for docker validation
    systemctl("stop firewalld");
    systemctl("restart docker");
    systemctl("is-active firewalld", expect_false => 1);
    systemctl("is-active docker");

    script_retry("docker pull $test_image", retry => 3, delay => 60, timeout => 180);

    # Start nginx in docker and validate initial ingress connectivity
    assert_script_run("docker run -d --name nginx --rm $test_image");
    my $nginx_docker_ip = script_output("docker container inspect nginx -f '{{ .NetworkSettings.IPAddress }}'");
    script_retry("curl $nginx_docker_ip -svo/dev/null", retry => 3, delay => 6);

    # Validate initial docker egress connectivity
    assert_script_run("docker run --rm $test_image $test_egress_cmd");

    # Start firewalld and validate docker connectivity
    systemctl("restart firewalld");
    systemctl("is-active firewalld");
    if (script_run("curl $nginx_docker_ip -svo/dev/null") != 0) { bsc_1214080("ingress docker connection failed"); }
    if (script_run("docker run --rm $test_image $test_egress_cmd") != 0) { bsc_1214080("egress docker connection failed"); }

    # Once more validate podman connectivity with firewalld restarted
    if (script_run("curl $nginx_podman_ip -svo/dev/null") != 0) { bsc_1214080("ingress podman connection failed"); }
    if (script_run("podman run --rm $test_image $test_egress_cmd") != 0) { bsc_1214080("egress podman connection failed"); }
}

sub bsc_1213811 {
    my $message = shift;
    record_soft_failure("bsc#1213811 - podman network unreachable after starting docker: $message");

    # Fail if backend is netavark, since it should not manifest any issues
    assert_script_run("podman info -f '{{ .Host.NetworkBackend }}' | grep -qv netavark");
}

sub bsc_1214080 {
    my $message = shift;
    record_soft_failure("bsc#1214080 - docker network broken after firewalld restart, if firewalld is disabled: $message");
}

sub cleanup {
    my $self = shift;
    my $podman = $self->containers_factory('podman');
    $podman->cleanup_system_host();
    my $docker = $self->containers_factory('docker');
    $docker->cleanup_system_host();
}

sub post_run_hook {
    my $self = shift;
    cleanup($self);
}

sub post_fail_hook {
    my $self = shift;
    cleanup($self);
}

1;
