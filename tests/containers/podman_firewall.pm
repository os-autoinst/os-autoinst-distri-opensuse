# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman firewalld
# Summary: Test podman with enabled firewall
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'script_retry';
use containers::utils qw(registry_url container_ip);
use containers::common 'check_containers_connectivity';
use Utils::Systemd 'systemctl';

my $stop_firewall = 0;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $podman = $self->containers_factory('podman');
    my $container_name = 'sut_container';

    # Test firewall only on systems where it's installed
    die('Firewall is not present.') unless ($self->firewall() == 'firewalld' && script_run('which ' . $self->firewall()) == 0);

    # Start firewall if it was not running before
    if (script_run('systemctl is-active ' . $self->firewall()) != 0) {
        systemctl('start ' . $self->firewall());
        $stop_firewall = 1;
    }

    # cni-podman0 interface is created when running the first container
    assert_script_run "podman pull " . registry_url('alpine');
    assert_script_run "podman run --rm " . registry_url('alpine');
    validate_script_output('ip a s cni-podman0', sub { /,UP/ });

    # Run container in the background
    assert_script_run "podman pull " . registry_url('alpine');
    assert_script_run "podman run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine') . " sleep 30d";

    # Cheking rules of specific running container
    validate_script_output("iptables -vn -t nat -L PREROUTING", sub { /CNI-HOSTPORT-DNAT/ });
    validate_script_output("iptables -vn -t nat -L POSTROUTING", sub { /CNI-HOSTPORT-MASQ/ });

    # Kill the container running on background (this may take some time)
    assert_script_run "podman kill $container_name ";
    script_retry "podman ps -q | wc -l | grep 0", delay => 5, retry => 12;

    # Test the connectivity of Podman containers
    check_containers_connectivity($podman);

    # Stop the firewall if it was started by this test module
    systemctl('stop ' . $self->firewall()) if $stop_firewall;
}

sub post_fail_hook {
    my ($self) = @_;

    # Stop the firewall if it was started by this test module
    systemctl('stop ' . $self->firewall()) if $stop_firewall;

    $self->SUPER::post_fail_hook;
}

1;
