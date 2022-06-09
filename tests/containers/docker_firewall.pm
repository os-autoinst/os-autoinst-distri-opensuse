# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker firewalld
# Summary: Test docker with enabled firewall
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils 'script_retry';
use version_utils qw(is_sle is_leap);
use containers::utils qw(registry_url container_ip);
use containers::common 'check_containers_connectivity';
use Utils::Systemd 'systemctl';

my $stop_firewall = 0;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $engine = $self->containers_factory('docker');
    my $container_name = 'sut_container';

    # Test firewall only on systems where it's installed
    die('Firewall is not present.') unless ($self->firewall() == 'firewalld' && script_run('which ' . $self->firewall()) == 0);

    # Start firewall if it was not running before
    if (script_run('systemctl is-active ' . $self->firewall()) != 0) {
        systemctl('start ' . $self->firewall());
        systemctl('restart docker');
        $stop_firewall = 1;
    }

    # Network interface docker0 is DOWN when no containers are running
    die 'No containers should be running!' if (script_output('docker ps -q | wc -l') != 0);
    validate_script_output('ip a s docker0', sub { /state DOWN/ });

    # Docker zone is created for docker version >= 20.10 (Tumbleweed), but it
    # is backported to docker 19 for SLE15-SP3 and for Leap 15.3
    unless (is_sle('<15-sp3') || is_leap("<15.3")) {
        assert_script_run "firewall-cmd --list-all --zone=docker";
        validate_script_output "firewall-cmd --list-interfaces --zone=docker", sub { /docker0/ };
        validate_script_output "firewall-cmd --get-active-zones", sub { /docker/ };
    }
    # Rules applied before DOCKER. Default is to listen to all tcp connections
    # ex. output: "1           0        0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0"
    validate_script_output "iptables -L DOCKER-USER -nvx --line-numbers", sub { /1.+all.+0\.0\.0\.0\/0\s+0\.0\.0\.0\/0/ };

    # Run container in the background
    script_retry "docker pull " . registry_url('alpine'), retry => 3, delay => 120;
    assert_script_run "docker run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine') . " sleep 30d";
    my $container_ip = container_ip($container_name, 'docker');

    # Each running container should have added a new entry to the DOCKER zone.
    # ex. output: "1           0        0 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:1234"
    validate_script_output "iptables -L DOCKER -nvx --line-numbers", sub { /1.+ACCEPT.+!docker0 docker0.+$container_ip\s+tcp dpt:1234/ };

    # Kill the container running on background (this may take some time)
    assert_script_run "docker kill $container_name ";
    script_retry "docker ps -q | wc -l | grep 0", delay => 5, retry => 12;

    # Test the connectivity of Docker containers
    check_containers_connectivity($engine);

    # Stop the firewall if it was started by this test module
    if ($stop_firewall == 1) {
        systemctl('stop ' . $self->firewall());
        systemctl('restart docker');
    }
}

sub post_fail_hook {
    my ($self) = @_;

    # Stop the firewall if it was started by this test module
    if ($stop_firewall == 1) {
        systemctl('stop ' . $self->firewall());
        systemctl('restart docker');
    }

    $self->SUPER::post_fail_hook;
}

1;
