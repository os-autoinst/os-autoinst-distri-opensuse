# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: install and verify Kea DHCP server container.
# Maintainer:  QE Core <qe-core@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use utils qw(set_hostname);
use testapi;
use lockapi;
use serial_terminal 'select_serial_terminal';
use mm_network 'setup_static_mm_network';
use Utils::Systemd qw(disable_and_stop_service systemctl check_unit_file);

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');

    barrier_create('DHCP_SERVER_READY', 2);
    barrier_create('DHCP_SERVER_FINISHED', 2);
    mutex_create 'barrier_setup_done';

    select_serial_terminal;
    record_info("ip a", script_output("ip a"));

    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.101 server master" >> /etc/hosts');

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall) if check_unit_file($self->firewall);

    setup_static_mm_network('10.0.2.101/24');
    record_info("ip a", script_output("ip a"));

    # Set the hostname
    set_hostname $hostname;

    install_dhcp_container();

    barrier_wait 'DHCP_SERVER_READY';
    barrier_wait 'DHCP_SERVER_FINISHED';
    # Kill the container running on background
    script_run("podman kill kea-dhcp4");
    script_output("podman logs kea-dhcp4 | tee server.log");
    upload_logs 'server.log';

}

sub install_dhcp_container {
    my $image = get_var('CONTAINER_IMAGE_TO_TEST', 'registry.opensuse.org/suse/alp/workloads/tumbleweed_containerfiles/suse/alp/workloads/kea:latest');
    # Instaling the container image
    assert_script_run("podman container runlabel install $image");

    # Copy the configured kea-dhcp4 config file to the container host and add the network interface name to listen on DHCP4 server
    my $nm_list = script_output("nmcli -t -f DEVICE,NAME c | head -n1");
    my ($device, $nm_id) = split(':', $nm_list);
    assert_script_run('curl -v -o /etc/kea/kea-dhcp4.conf  ' . data_url('kea-dhcp/kea-dhcp4.conf'));
    assert_script_run("cat  /etc/kea/kea-dhcp4.conf");
    assert_script_run("sed -i -e 's/\"interfaces\": \\[ \\]/\"interfaces\": \[ \" $device \" \]/' /etc/kea/kea-dhcp4.conf");

    # Start the dhcp4 container in the background
    assert_script_run("podman run -itd --replace --name kea-dhcp4 --privileged --network=host -v /etc/kea:/etc/kea $image  kea-dhcp4 -c /etc/kea/kea-dhcp4.conf");
    validate_script_output('podman ps ', sub { m/kea-dhcp4/ });
    # cni-podman0 interface is created when running the first container
    validate_script_output('ip a s cni-podman0', sub { /,UP/ });
    validate_script_output('ss -lnp', sub { /10.0.2.101:67/ });
}

sub post_fail_hook {
    my ($self) = @_;
    script_run("podman kill kea-dhcp4");
    script_output("podman logs kea-dhcp4 | tee server.log");
    upload_logs 'server.log';

    $self->SUPER::post_fail_hook;
}
1;

