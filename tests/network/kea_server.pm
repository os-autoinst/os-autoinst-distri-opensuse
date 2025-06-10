# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: kea
# Summary: Basic kea test
# - configure Kea dhcp4 with predefined config file
# - start the Kea dhcp4 server and validate the config file
# - enable DHCP on the client and reload network settings
# - verify client assigned IP is within the pool
# - verify client assigned IP changed from pre-set IP
# - check the Kea lease file
# - check the Kea logs for full DHCP handshake
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils qw(zypper_call systemctl);
use network_utils 'iface';
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle is_tumbleweed);

sub run {
    select_serial_terminal;
    mutex_create('kea_server_ready');
    barrier_create('kea_dhcp', 2);

    my $server_nic = iface();
    my $config = 'network_bonding/kea-dhcp4.conf';
    zypper_call('in kea');

    assert_script_run("curl -v -o /etc/kea/kea-dhcp4.conf " . data_url($config));
    assert_script_run("sed -i 's/\"eth0\"/\"$server_nic\"/' /etc/kea/kea-dhcp4.conf") unless $server_nic eq 'eth0';
    assert_script_run("kea-dhcp4 -t /etc/kea/kea-dhcp4.conf", fail_message => 'Kea dhcp4 config invalid');

    my $package = (is_sle('>=16') || is_tumbleweed) ? 'kea-dhcp4' : 'kea';
    systemctl("enable --now $package");
    systemctl("is-active $package");

    barrier_wait('kea_dhcp');

    my $lease_file = '/var/lib/kea/kea-leases4.csv';
    record_info("Lease file", script_output("cat $lease_file"));
    die("Lease file only has header, no lease assigned") if script_output("wc -l < $lease_file") < 2;
    my $dhcp_log = script_output("grep -E 'DHCP(DISCOVER|OFFER|REQUEST|ACK)' /var/log/kea/kea.log");
    record_info("DHCP handshake", $dhcp_log);
    assert_script_run("grep -Pz '(?s)(?=.*DHCPDISCOVER)(?=.*DHCPOFFER)(?=.*DHCPREQUEST)(?=.*DHCPACK)' /var/log/kea/kea.log", fail_message => "Missing one or more DHCP handshake keywords in kea log");
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    upload_logs('/var/log/kea/kea.log');
}

1;
