# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate docker and podman network interoperability
# - validate if podman and docker networking works together
# - check if firewalld doesn't break either
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(containers::basetest);
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use utils;
use containers::common qw(install_packages);
use Utils::Logging 'save_and_upload_log';

my $port = 8000;
my $test_image = "registry.opensuse.org/opensuse/nginx";
my $test_url = "https://registry.opensuse.org/v2/";

sub run_tests {
    my $ip_version = shift;

    # Get our IP address
    my $try_addr = ($ip_version == 6) ? "2001:4860:4860::8888" : "8.8.8.8";
    my $ip_addr = script_output "ip -$ip_version --json route get $try_addr | jq -Mr '.[0].prefsrc'", proceed_on_failure => 1;
    return unless ($ip_addr =~ /^[0-9]/);
    $ip_addr = "[$ip_addr]" if ($ip_version == 6);

    my $volumes = '-v $HOME/nginx/nginx.conf:/etc/nginx/nginx.conf:ro,z -v $HOME/nginx:/usr/share/nginx/html:ro,z';
    my $curl_opts = "-$ip_version -L";
    my @containers;

    # Create rootfull & rootless containers on both podman & docker
    for my $runtime ("docker", "podman") {
        for my $type ("root", "rootless") {
            my $name = "test_${type}_${runtime}_${ip_version}";
            my $sudo = ($type eq "root") ? "sudo" : "";
            my $network = "";

            if ($ip_version == 6 && $runtime eq "podman") {
                # For IPv6 we need to create a network. IPv4 uses NAT. IPv6 uses routing tables
                $network = "ip6net";
                assert_script_run "$sudo $runtime network create --ipv6 $network";
                assert_script_run "$sudo $runtime network inspect $network";
                $network = "--network $network";
            }

            script_retry("$sudo $runtime pull $test_image", retry => 3, delay => 60, timeout => 180);
            assert_script_run "$sudo $runtime run -d --name $name $network -p $port:80 $volumes $test_image";
            push @containers, {name => $name, runtime => $runtime, sudo => $sudo, port => $port};
            $port++;
        }
    }

    # Test connectivity to all containers on localhost
    for my $container (@containers) {
        # FIXME: This doesn't work yet
        next if ($container->{name} eq "test_root_podman_6");
        assert_script_run "curl $curl_opts http://localhost:$container->{port}",
          fail_message => "failed IPv$ip_version localhost test for $container->{name}";
    }

    # Test connectivity to all containers on IP address
    for my $container (@containers) {
        assert_script_run "curl $curl_opts http://$ip_addr:$container->{port}",
          fail_message => "failed IPv$ip_version test for $container->{name}";
    }

    # Skip this test for IPv6 as it may fail on unconfigured openQA workers
    if ($ip_version != 6) {
        # Test container connectivity to the outside world
        for my $container (@containers) {
            # This doesn't seem to work on o3
            assert_script_run "$container->{sudo} $container->{runtime} exec $container->{name} curl $curl_opts $test_url",
              fail_message => "failed IPv$ip_version Internet test for $container->{name}";
        }
    }

    # Cleanup
    for my $container (@containers) {
        assert_script_run "$container->{sudo} $container->{runtime} rm -vf $container->{name}";
        assert_script_run "$container->{sudo} $container->{runtime} rmi $test_image";
    }
}

sub run {
    select_serial_terminal;

    my @pkgs = ("docker", "podman", "jq");
    install_packages(@pkgs);

    # https://docs.docker.com/engine/daemon/ipv6/
    assert_script_run "sed -i 's%^{%&\"ipv6\":true,\"fixed-cidr-v6\":\"2001:db8:1::/64\",%' /etc/docker/daemon.json";
    record_info("docker daemon.json", script_output("cat /etc/docker/daemon.json"));
    systemctl "enable --now docker";

    record_info("docker root", script_output("docker info"));
    my $warnings = script_output("docker info -f '{{ range .Warnings }}{{ println . }}{{ end }}'");
    record_info("WARNINGS daemon", $warnings) if $warnings;
    $warnings = script_output("docker info -f '{{ range .ClientInfo.Warnings }}{{ println . }}{{ end }}'");
    record_info("WARNINGS client", $warnings) if $warnings;
    record_info("docker version", script_output("docker version"));
    record_info("podman root", script_output("podman info"));

    # Needed to avoid:
    # WARNING: COMMAND_FAILED: '/sbin/iptables -t nat -F DOCKER' failed: iptables: No chain/target/match by that name.
    # See https://bugzilla.suse.com/show_bug.cgi?id=1196801
    systemctl "restart firewalld";
    systemctl "status firewalld";

    assert_script_run "echo '$testapi::username ALL=(ALL:ALL) NOPASSWD: ALL' | tee -a /etc/sudoers.d/nopasswd";

    # Check for bsc#1255069
    if (script_run "podman run --rm $test_image curl -sLf -m 10 $test_url") {
        record_soft_failure "bsc#1255069 - docker denies podman access to network";

        # Running podman as root with docker installed may be problematic as netavark uses nftables
        # while docker still uses iptables.
        # Use workaround suggested in:
        # - https://fedoraproject.org/wiki/Changes/NetavarkNftablesDefault#Known_Issue_with_docker
        # - https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-on-a-router
        assert_script_run "iptables -I DOCKER-USER -j ACCEPT";
        assert_script_run "ip6tables -I DOCKER-USER -j ACCEPT";
    }

    select_user_serial_terminal;

    # https://docs.docker.com/engine/security/rootless/
    assert_script_run "dockerd-rootless-setuptool.sh install";
    systemctl "--user enable --now docker";

    record_info("docker rootless", script_output("docker info"));
    record_info("podman rootless", script_output("podman info"));

    assert_script_run "mkdir -m 755 nginx";
    assert_script_run('curl -sLf -vo $HOME/nginx/nginx.conf ' . data_url('containers/nginx/') . 'nginx.conf');
    assert_script_run('curl -sLf -vo $HOME/nginx/index.html ' . data_url('containers/nginx/') . 'index.html');
    assert_script_run "chmod 644 nginx/*";

    for my $ip_version (4, 6) {
        record_info "IPv$ip_version tests";
        run_tests($ip_version);
    }
}

sub cleanup {
    for my $runtime ("docker", "podman") {
        for my $sudo ("", "sudo") {
            script_run "$sudo $runtime system prune -a -f";
        }
    }
}

sub post_run_hook {
    cleanup;
}

sub post_fail_hook {
    for my $ip_version (4, 6) {
        save_and_upload_log("ip -$ip_version addr", "/tmp/ip${ip_version}addr.txt");
        save_and_upload_log("ip -$ip_version route", "/tmp/ip${ip_version}route.txt");
    }
    save_and_upload_log("sudo nft list ruleset", "/tmp/nft.txt");
    save_and_upload_log("sudo ss -tnlp", "/tmp/tcp_services.txt");
    save_and_upload_log("sudo sysctl -a | grep ^net", "/tmp/net_sysctl.txt");

    for my $runtime ("docker", "podman") {
        for my $sudo ("", "sudo") {
            my @containers = split(/\n/, script_output "$sudo $runtime ps -a --format '{{.Names}}'");
            for my $container (@containers) {
                script_run "$sudo $runtime logs $container";
                script_run "$sudo $runtime inspect $container";
                script_run "$sudo $runtime rm -vf $container";
            }
            script_run "$sudo $runtime rmi \$($sudo $runtime images -q)";
        }
    }

    cleanup;
}

sub test_flags {
    return {always_rollback => 1};
}

1;
