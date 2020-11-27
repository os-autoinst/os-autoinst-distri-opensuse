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
my $service_type = 'Systemd';

sub install_service {
    # dhcp contains common files while dhcp-server is for server.
    zypper_call('in dhcp');
    zypper_call('in dhcp-server');
}

# Assume that we are using a 24 bit netmask.
sub get_subnet_3 {
    my ($iface) = @_;
    my $ip;
    if ($service_type eq 'Systemd') {
        $ip = script_output("ip -br -4 addr | grep $iface | sed 's/\\s\\+/:/g' | cut -d ':' -f 3 | cut -d '/' -f 1", type_command => 1);
    } else {
        $ip = script_output("ip -4 addr | grep $iface | grep -v $iface: | cut -d '/' -f1 | awk \'{print \$2}\'", type_command => 1);
    }
    my @arr = split(/\./, $ip);
    return join(".", @arr[0 .. 2]);
}

sub config_service {
    # Get first active network interface name.
    my $iface;
    if ($service_type eq 'Systemd') {
        $iface = script_output("ip -br -4 addr | grep -v '^lo' | grep 'UP' | head -n 1 | cut -d ' ' -f 1", type_command => 1);
    } else {
        $iface = script_output("ip -4 addr | grep -v 'lo:' | grep -w UP | cut -d ' ' -f2 | sed s/://g", type_command => 1);
    }
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
    common_service_action 'dhcpd', $service_type, 'enable';
}

sub start_service {
    common_service_action 'dhcpd', $service_type, 'start';
}

sub stop_service {
    common_service_action 'dhcpd', $service_type, 'stop';
}

sub check_service {
    common_service_action 'dhcpd', $service_type, 'is-enabled';
    common_service_action 'dhcpd', $service_type, 'is-active';
}

# Check dhcp service before and after migration.
# Stage is 'before' or 'after' system migration.
sub full_dhcpd_check {
    my ($stage, $type) = @_;
    $stage //= '';
    $service_type = $type;
    if ($stage eq 'before') {
        install_service();
        config_service();
        enable_service();
        start_service();
    }
    check_service();
}

1;
