# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for docker specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::docker;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url get_docker_version check_runtime_version container_ip);
use containers::common qw(install_docker_when_needed);
use version_utils qw(is_sle is_leap);
use utils qw(systemctl file_content_replace);
use version_utils qw(get_os_release);
has runtime => 'docker';

sub init {
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);
    configure_insecure_registries();
}

sub configure_insecure_registries {
    my ($self) = shift;
    my $registry = registry_url();
    # Allow our internal 'insecure' registry
    assert_script_run(
        'echo "{ \"debug\": true, \"insecure-registries\" : [\"localhost:5000\", \"registry.suse.de\", \"' . $registry . '\"] }" > /etc/docker/daemon.json');
    assert_script_run('cat /etc/docker/daemon.json');
    systemctl('restart docker');
    record_info "setup $self->runtime", "deamon.json ready";
}

sub check_containers_firewall {
    record_info "firewall", "Checking that firewall is enabled, properly configured and containers can reach the Internet";
    my $container_name = 'sut_container';
    my $docker_version = get_docker_version();
    systemctl('is-active firewalld');
    my $running = script_output qq(docker ps -q | wc -l);
    validate_script_output('ip a s docker0', sub { /state DOWN/ }) if $running == 0;
    # Docker zone is created for docker version >= 20.10 (Tumbleweed), but it
    # is backported to docker 19 for SLE15-SP3 and for Leap 15.3
    if (check_runtime_version($docker_version, ">=20.10") || is_sle('>=15-sp3') || is_leap(">=15.3")) {
        assert_script_run "firewall-cmd --list-all --zone=docker";
        validate_script_output "firewall-cmd --list-interfaces --zone=docker", sub { /docker0/ };
        validate_script_output "firewall-cmd --get-active-zones", sub { /docker/ };
    }
    # Rules applied before DOCKER. Default is to listen to all tcp connections
    # ex. output: "1           0        0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0"
    validate_script_output "iptables -L DOCKER-USER -nvx --line-numbers", sub { /1.+all.+0\.0\.0\.0\/0\s+0\.0\.0\.0\/0/ };

    # Run container in the background
    assert_script_run "docker run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine');
    my $container_ip = container_ip($container_name, 'docker');

    # Each running container should have added a new entry to the DOCKER zone.
    # ex. output: "1           0        0 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:1234"
    validate_script_output "iptables -L DOCKER -nvx --line-numbers", sub { /1.+ACCEPT.+!docker0 docker0.+$container_ip\s+tcp dpt:1234/ };

    # Connectivity to host check
    my $default_route = script_output "docker run " . registry_url('alpine') . " ip route show default | awk \'/default/ {print \$3}\'";
    assert_script_run "docker run --rm " . registry_url('alpine') . " ping -c3 " . $default_route;

    # Cross-container connectivity check
    assert_script_run "docker run --rm " . registry_url('alpine') . " ping -c3 " . $container_ip;

    # Outisde connectivity check
    assert_script_run "docker run --rm " . registry_url('alpine') . " wget google.com";

    # Kill the container running on background
    assert_script_run "docker kill $container_name ";
}

1;
