# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper module for IPv6 tests
# Maintainer: Jose Lausuch <jalausuch@suse.com>

package wicked::IPv6;

use Mojo::Base 'wickedbase';
use testapi;

sub evaluate_step {
    my ($self, $cmd, $value, $should_not) = @_;
    my $output = script_output($cmd);
    record_info('output', "cmd: $cmd \noutput:\n$output");
    if ($should_not && $output =~ $value) {
        record_info('FAIL', "$value is not expected");
        return 1;
    }
    elsif (!$should_not && $output !~ $value) {
        record_info('FAIL', "$value is expected");
        return 1;
    }
    return 0;
}

sub setup_interface {
    my ($self, %args) = @_;
    die '$args{iface} is required'      unless $args{iface};
    die '$args{ifcfg_type} is required' unless $args{ifcfg_type};
    record_info("STEP", 'Setup ' . $args{ifcfg_type} . ' interface ' . $args{iface});
    $self->get_from_data('wicked/' . $args{ifcfg_type} . '_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $args{iface});
    $self->wicked_command('ifup', $args{iface});
}

sub wait_for_router_announcement {
    my ($self, %args) = @_;
    die '$args{iface} is required' unless $args{iface};
    record_info("STEP", 'Let ' . $args{iface} . ' wait for a router announcement');
    assert_script_run('rdisc6 ' . $args{iface});
}

sub retrigger_dhcp_requests {
    my ($self, %args) = @_;
    die '$args{iface} is required' unless $args{iface};
    record_info("STEP", 'Retrigger DHCP requests');
    $self->wicked_command('ifdown', $args{iface});
    $self->wicked_command('ifup',   $args{iface});
}

sub obtain_address_by_dhcpv4 {
    my ($self, %args) = @_;
    die '$args{iface} is required' unless $args{iface};
    record_info("STEP", $args{iface} . ' should' . ($args{should_not} ? ' NOT' : '') . ' obtain an address by DHCPv4');
    # ip address show dev eth0
    # out.should include "inet #{DHCP4_SUT0}"
    # out.should_not include "inet #{DHCP4_SUT0}"
    my $cmd = 'ip address show dev ' . $args{iface};
    return $self->evaluate_step($cmd, $self->get_ip(type => 'dhcp4'), $args{should_not});
}

sub obtain_autonomous_ipv6_address {
    my ($self, %args) = @_;
    die '$args{iface} is required' unless $args{iface};
    record_info("STEP", $args{iface} . ' should' . ($args{should_not} ? ' NOT' : '') . ' obtain an an autonomous IPv6 address');
    # ip -6 address show dev eth0
    # out.should include "inet6 #{RADVD_SUT0}"
    # out.should_not include "inet6 #{RADVD_SUT0}"
    my $cmd = 'ip -6 address show dev ' . $args{iface};
    return $self->evaluate_step($cmd, $self->get_ip(type => 'ipv6'), $args{should_not});
}

sub obtain_address_by_dhcpv6 {
    my ($self, %args) = @_;
    die '$args{iface} is required' unless $args{iface};
    record_info("STEP", $args{iface} . ' should' . ($args{should_not} ? ' NOT' : '') . ' obtain an address by DHCPv6');
    # ip -6 address show dev eth0
    # out.should include "inet6 #{DHCP6_SUT0}"
    # out.should_not include "inet6 #{DHCP6_SUT0}"
    my $cmd = 'ip -6 address show dev ' . $args{iface};
    return $self->evaluate_step($cmd, $self->get_ip(type => 'dhcp6'), $args{should_not});
}

sub no_address_should_be_tentative {
    my ($self, %args) = @_;
    die '$args{iface} is required' unless $args{iface};
    record_info("STEP", 'No address should be tentative');
    # ip -6 address show dev eth0
    # out.should_not include "tentative"
    my $cmd = 'ip address show dev ' . $args{iface};
    my $output = script_output($cmd);
    record_info('output', "cmd: $cmd \noutput:\n$output");
    my $errors = 0;
    unless ($output !~ /tentative/) {
        record_info('FAIL', 'tentative word presented');
        $errors += 1;
    }
    my $ipv6_network_prefix = $self->get_ip(type => 'ipv6');
    unless ($output =~ /inet6 $ipv6_network_prefix/m) {
        record_info('FAIL', 'no prefix for local network route');
        $errors += 1;
    }
    return $errors;
}


sub obtain_default_ipv6_route {
    my ($self, %args) = @_;
    die '$args{iface} is required' unless $args{iface};
    record_info("STEP", $args{iface} . ' should' . ($args{should_not} ? ' NOT' : '') . ' obtain a default IPv6 route');
    # I [should|should not] obtain a default IPv6 route
    # ip -6 route show dev eth0
    # out.should match "^#{RADVD_SUT0}"
    # out.should_not match "^#{RADVD_SUT0}"
    my $cmd = 'ip -6 r s ';
    #my $errors = $self->evaluate_step($cmd, $self->get_ip(type => 'ipv6'), $args{should_not});
    my $errors = $self->evaluate_step($cmd, 'default', $args{should_not});
    my $cmd = 'ip -6 -o r s ';
    my $errors += $self->evaluate_step($cmd, $self->get_ip(type => 'ipv6'), $args{should_not});
    return $errors;
}

sub obtain_default_dns_server_by_dhcpv4 {
    my ($self, %args) = @_;
    record_info("STEP", 'Should' . ($args{should_not} ? ' NOT' : '') . ' obtain a DNS server by DHCPv4');
    # I [should|should not] obtain a DNS server by DHCPv4
    # cat /etc/resolv.conf
    # out.should include "nameserver #{DHCP4_REF0}"
    # out.should_not include "nameserver #{DHCP4_REF0}"
    my $cmd = 'cat /etc/resolv.conf';
    return $self->evaluate_step($cmd, $self->get_ip(type => 'dhcp4', is_wicked_ref => 1), $args{should_not});
}

sub obtain_default_dns_server_by_dhcpv6 {
    my ($self, %args) = @_;
    record_info("STEP", 'Should' . ($args{should_not} ? ' NOT' : '') . ' obtain a DNS server by DHCPv6');
    # I [should|should not] obtain a DNS server by DHCPv6
    # cat /etc/resolv.conf
    # out.should include "nameserver #{DHCP6_REF0}"
    # out.should_not include "nameserver #{DHCP6_REF0}"
    my $cmd = 'cat /etc/resolv.conf';
    return $self->evaluate_step($cmd, $self->get_ip(type => 'dhcp6', is_wicked_ref => 1), $args{should_not});
}

1;
