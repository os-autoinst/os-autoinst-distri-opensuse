# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Managed off, other off, prefix length != 64
#   When radvd is set to managed off, other off, prefix length != 64
#   And I set up static IP addresses for eth0 from legacy files
#   And I let eth0 wait for a router announcement
#   And I retrigger DHCP requests
#   Then I should not obtain an address by DHCPv4
#   And I should not obtain an autonomous IPv6 address
#   And I should not obtain an address by DHCPv6
#   And no address should be tentative
#   And I should obtain a default IPv6 route
#   And I should not obtain a DNS server by DHCPv4
#   And I should not obtain a DNS server by DHCPv6
#
# https://github.com/openSUSE/wicked-testsuite/blob/master/features/wicked_6_ipv6.feature#L18
#
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base wicked::IPv6;
use strict;
use warnings;
use lockapi;
use testapi;

sub run {
    my ($self, $ctx) = @_;
    mutex_wait('radvdipv6t01');
    my $iface = $ctx->iface();
    my $errors = 0;
    $self->setup_interface(iface => $iface, ifcfg_type => 'static');
    $self->wait_for_router_announcement(iface => $iface);
    $self->retrigger_dhcp_requests(iface => $iface);
    $errors += $self->obtain_address_by_dhcpv4(iface => $iface, should_not => 1);
    $errors += $self->obtain_autonomous_ipv6_address(iface => $iface, should_not => 1);
    $errors += $self->obtain_address_by_dhcpv6(iface => $iface, should_not => 1);
    $errors += $self->no_address_should_be_tentative(iface => $iface);
    $errors += $self->obtain_default_ipv6_route(iface => $iface);
    $errors += $self->obtain_default_dns_server_by_dhcpv4(should_not => 1);
    $errors += $self->obtain_default_dns_server_by_dhcpv6(should_not => 1);
    die('Some test(s) failed') if ($errors);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
