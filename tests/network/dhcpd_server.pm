# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dhcp-server
# Summary: dhcpd server test
# - install and configure ISC dhcpd
# - validate the dhcpd configuration
# - start the dhcpd server
# - wait for a client DHCP transaction
# - verify a lease was assigned
# - verify the full DHCP handshake in the server logs
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use lockapi;
use utils 'systemctl';
use network_utils 'iface';
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';

sub run {
    select_serial_terminal;

    my $server_nic = iface();
    my $config = 'network_bonding/dhcpd.conf';

    install_package('dhcp-server', trup_reboot => 1);

    barrier_create('dhcpd', 2);

    record_info("dhcp-server", script_output("rpm -q dhcp-server"));

    assert_script_run("curl -v -o /etc/dhcpd.conf " . data_url($config));
    assert_script_run("dhcpd -t -cf /etc/dhcpd.conf", fail_message => 'dhcpd configuration is invalid');
    assert_script_run("sed -i 's/^DHCPD_INTERFACE=\"\"/DHCPD_INTERFACE=\"$server_nic\"/' /etc/sysconfig/dhcpd");

    systemctl("enable --now dhcpd");
    systemctl("is-active dhcpd");

    mutex_create('dhcpd_server_ready');
    barrier_wait('dhcpd');

    my $lease_file = '/var/lib/dhcp/db/dhcpd.leases';

    assert_script_run("test -f $lease_file", fail_message => "dhcpd lease file not found");

    record_info("Lease file", script_output("cat $lease_file"));

    assert_script_run("grep -q '^lease 10\\.0\\.2\\.' $lease_file", fail_message => "No DHCP lease from 10.0.2.0/24 found");

    assert_script_run("journalctl -u dhcpd --no-pager > /tmp/dhcpd.log");

    my $dhcp_log = script_output("grep -E 'DHCP(DISCOVER|OFFER|REQUEST|ACK)' /tmp/dhcpd.log");

    record_info("DHCP handshake", $dhcp_log);
    assert_script_run("grep -Pz '(?s)(?=.*DHCPDISCOVER)(?=.*DHCPOFFER)(?=.*DHCPREQUEST)(?=.*DHCPACK)' /tmp/dhcpd.log", fail_message => "Missing one or more DHCP handshake keywords in dhcpd log");
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    upload_logs('/tmp/dhcpd.log');
}

1;
