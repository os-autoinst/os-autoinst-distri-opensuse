# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for podman specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::podman;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url container_ip);
use containers::common qw(install_podman_when_needed);
use utils qw(file_content_replace);
use Utils::Systemd 'systemctl';
use version_utils qw(get_os_release);
has runtime => "podman";

sub init {
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_podman_when_needed($host_distri);
    configure_insecure_registries();
}

sub configure_insecure_registries {
    my ($self) = shift;
    my $registry = registry_url();

    assert_script_run "curl " . data_url('containers/registries.conf') . " -o /etc/containers/registries.conf";
    assert_script_run "chmod 644 /etc/containers/registries.conf";
    file_content_replace("/etc/containers/registries.conf", REGISTRY => $registry);
}

sub check_containers_firewall {
    my ($runtime) = @_;
    record_info "firewall", "Checking that firewall is enabled, properly configured and containers can reach the Internet";
    my $container_name = 'sut_container';
    systemctl('is-active firewalld');

    # cni-podman0 interface is created when running the first container
    assert_script_run "podman pull " . registry_url('alpine');
    assert_script_run "podman run --rm " . registry_url('alpine');
    validate_script_output('ip a s cni-podman0', sub { /,UP/ });

    # Run container in the background
    assert_script_run "podman pull " . registry_url('alpine');
    assert_script_run "podman run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine');
    my $container_ip = container_ip $container_name, 'podman';

    # Cheking rules of specific running container
    validate_script_output("iptables -vn -t nat -L PREROUTING", sub { /CNI-HOSTPORT-DNAT/ });
    validate_script_output("iptables -vn -t nat -L POSTROUTING", sub { /CNI-HOSTPORT-MASQ/ });

    # Connectivity to host check
    my $default_route = script_output "podman run " . registry_url('alpine') . " ip route show default | awk \'/default/ {print \$3}\'";
    assert_script_run "podman run --rm " . registry_url('alpine') . " ping -c3 " . $default_route;

    # Cross-container connectivity check
    assert_script_run "podman run --rm " . registry_url('alpine') . " ping -c3 " . $container_ip;

    # Outside connectivity check
    assert_script_run "podman run --rm " . registry_url('alpine') . " wget google.com";

    # Kill the container running on background
    assert_script_run "podman kill $container_name";
}

1;
