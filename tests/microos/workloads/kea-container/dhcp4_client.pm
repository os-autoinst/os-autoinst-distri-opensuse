# SUSE"s openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman kea-container
# Summary: install and verify Kea DHCP server container.
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use warnings;
use strict;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use Utils::Systemd qw(disable_and_stop_service systemctl check_unit_file);

sub run {
    my ($self) = @_;

    mutex_wait 'barrier_setup_done';
    barrier_wait 'DHCP_SERVER_READY';

    select_serial_terminal;
    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall) if check_unit_file($self->firewall);

    assert_script_run('nmcli conn');
    my $nm_list = script_output("nmcli -t -f DEVICE,NAME c | head -n1");
    my ($device, $nm_id) = split(':', $nm_list);
    assert_script_run "nmcli connection modify '$nm_id' ipv4.method auto";
    assert_script_run("nmcli conn up '$nm_id'");
    assert_script_run('nmcli conn');

    record_info("ip a", script_output("ip a"));
    assert_script_run('ping -c 1 10.0.2.101');

    $nm_list = script_output("nmcli -t -f DEVICE,NAME c | head -n1");
    ($device, $nm_id) = split(':', $nm_list);
    validate_script_output("ip -4 addr show dev $device | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p'", sub { m/10.0.2.12[0-5]/ });
    #validate_script_output("$addr",  sub {m/10.0.2.12[0-5]/});
    barrier_wait 'DHCP_SERVER_FINISHED';
}
1;

