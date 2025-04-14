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
use network_utils qw(iface set_nic_dhcp_auto reload_connections_until_all_ips_assigned delete_all_existing_connections);
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    mutex_wait('kea_server_ready');

    my $iface = iface();
    delete_all_existing_connections();
    set_nic_dhcp_auto($iface);
    reload_connections_until_all_ips_assigned(nics => [$iface]);

    barrier_wait('kea_dhcp');

    my $ip_output = script_output("ip addr show $iface");
    if ($ip_output =~ /inet (10\.0\.2\.(\d+))(\/\d+)?/) {
        my $client_ip = $1;
        my $last_octet = $2;
        record_info("Assigned client IP", $client_ip);
        die "IP did not change" if ($last_octet == 102);
        die "Assigned IP $client_ip is not within pool (10.0.2.15 - 10.0.2.100)" unless ($last_octet >= 15 && $last_octet <= 100);
    }
}

1;
