# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Package for dhcp service tests
#
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

package services::dhcpd;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

sub install_service {
    # dhcp contains common files while dhcp-server is for server.
    zypper_call('in dhcp');
    zypper_call('in dhcp-server');
}

# Assume that we are using a 24 bit netmask.
sub get_subnet_3 {
    my ($iface) = @_;
    my $ip  = script_output("ip -br -4 addr | grep $iface | sed 's/\\s\\+/:/g' | cut -d ':' -f 3 | cut -d '/' -f 1", type_command => 1);
    my @arr = split(/\./, $ip);
    return join(".", @arr[0 .. 2]);
}

sub config_service {
    # Get first active network interface name.
    my $iface    = script_output("ip -br -4 addr | grep -v '^lo' | grep 'UP' | head -n 1 | cut -d ' ' -f 1", type_command => 1);
    my $subnet_3 = get_subnet_3($iface);
    # Setting dhcpd range in /etc/dhcpd.conf.
    type_string("echo '# Configuration for dhcpd test.' > /etc/dhcpd.conf\n");
    type_string("echo 'option domain-name \"aaa\";' >> /etc/dhcpd.conf\n");
    type_string("echo 'subnet $subnet_3.0 netmask 255.255.255.0 {' >> /etc/dhcpd.conf\n");
    type_string("echo '  range $subnet_3.253 $subnet_3.254;' >> /etc/dhcpd.conf\n");
    type_string("echo '}' >> /etc/dhcpd.conf\n");
    # dhchd reads interface from /etc/sysconfig/dhcpd.
    # While worker uses br0 as interface.
    type_string("sed -i 's/^DHCPD_INTERFACE=\"\\w*\"\$/DHCPD_INTERFACE=\"$iface\"/g' /etc/sysconfig/dhcpd\n");
}

sub enable_service {
    systemctl('enable dhcpd');
}

sub start_service {
    systemctl('start dhcpd');
}

sub stop_service {
    systemctl('stop dhcpd');
}

sub check_service {
    systemctl('is-enabled dhcpd');
    systemctl('is-active dhcpd');
}

# Check dhcp service before and after migration.
# Stage is 'before' or 'after' system migration.
sub full_dhcpd_check {
    my ($stage) = @_;
    $stage //= '';
    if ($stage eq 'before') {
        install_service();
        config_service();
        enable_service();
        start_service();
    }
    check_service();
}

1;
