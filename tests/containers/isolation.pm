# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: isolation
# Summary: Test container network isolation
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use containers::common qw(install_packages);
use utils;

my $runtime;
my $network = "test_isolated_network";

sub test_ip_version {
    my ($ip_version, $ip_addr) = @_;

    my $image = "registry.opensuse.org/opensuse/busybox";
    script_retry("$runtime pull $image", timeout => 300, delay => 60, retry => 3);

    # Test that containers can't access the host
    assert_script_run "! $runtime run --rm --network $network $image ping -$ip_version -c 1 $ip_addr";

    # Test that containers can't access the Internet
    # Google DNS servers
    my $external_ip = ($ip_version == 6) ? "2001:4860:4860::8888" : "8.8.8.8";
    assert_script_run "! $runtime run --rm --network $network $image ping -$ip_version -c 1 $external_ip";

    # Test that containers can't modify IP routes
    assert_script_run "! $runtime run --rm --privileged --cap-add=CAP_NET_ADMIN --network $network $image ip -$ip_version route add default via $ip_addr";
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;

    $runtime = $self->containers_factory($args->{runtime});
    my @packages = qw(jq);
    # rootless docker is not available on SLEM
    if ($args->{runtime} eq "docker") {
        my $base = check_var("CONTAINERS_DOCKER_FLAVOUR", "stable") ? "docker-stable" : "docker";
        push @packages, "$base-rootless-extras";
    }
    install_packages(@packages);

    my %ip_addr;
    for my $ip_version (4, 6) {
        my $iface = script_output "ip -$ip_version --json route list match default | jq -Mr '.[0].dev'";
        $ip_addr{$ip_version} = script_output "ip -$ip_version --json addr show $iface | jq -Mr '.[0].addr_info[0].local'";
    }

    my $ipv6_opts = ($args->{runtime} eq "docker") ? "--subnet 2001:db8::/64" : "";
    assert_script_run "$runtime network create --ipv6 $ipv6_opts --internal $network";
    for my $ip_version (4, 6) {
        record_info("Test IPv$ip_version");
        test_ip_version $ip_version, $ip_addr{$ip_version};
    }
    assert_script_run "$runtime network rm $network";

    return if check_var("VIRSH_VMM_FAMILY", "xen");
    select_user_serial_terminal;

    # https://docs.docker.com/engine/security/rootless/
    if ($args->{runtime} eq "docker") {
        assert_script_run "dockerd-rootless-setuptool.sh install";
        systemctl "--user enable --now docker";
    }

    assert_script_run "$runtime network create --ipv6 $ipv6_opts --internal $network";
    for my $ip_version (4, 6) {
        record_info("Test IPv$ip_version rootless");
        test_ip_version $ip_version, $ip_addr{$ip_version};
    }
    assert_script_run "$runtime network rm $network";

    select_serial_terminal;
}

1;

sub cleanup() {
    unless (check_var("VIRSH_VMM_FAMILY", "xen")) {
        select_user_serial_terminal;
        script_run "$runtime network rm $network";
        $runtime->cleanup_system_host();
        script_run "dockerd-rootless-setuptool.sh uninstall" if ($runtime->{runtime} eq "docker");
    }

    select_serial_terminal;
    script_run "$runtime network rm $network";
    $runtime->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup;
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup;
    $self->SUPER::post_run_hook;
}
