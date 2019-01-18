# Copyright (C) 2014-2017 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: - add the virtualization test suite- add a load_virtualization_tests call
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use virtmanager;

sub checking_vnet_result {
    my $net = shift;
    x11_start_program('xterm');
    send_key 'alt-f10';
    become_root();
    type_string 'virsh -c qemu:///system net-list';
    send_key 'ret';
    foreach my $vnet (@$net) {
        type_string "virsh -c qemu:///system net-info $vnet";
        send_key 'ret';
    }
    assert_screen 'virtman_vnetcheck';
}

sub go_for_vnet {
    my $vnet = shift;
    launch_virtmanager();
    # tab Virtual networks
    connection_details('virtualnet');
    create_vnet($vnet);
}


sub run {
    # define the Virtual network
    my $vnet = {
        name => 'vnettest',
        ipv4 => {
            active  => 'true',
            network => '192.168.100.0/24',
            dhcpv4  => {
                active => 'true',
                start  => '192.168.100.12',
                end    => '192.168.100.20',
            },
            staticrouteipv4 => {
                active => 'false',    # default
                tonet  => '',
                viagw  => '',
            },
        },
        ipv6 => {
            active  => 'false',
            network => 'fd00:dead:beef:55::/64',
            dhcpv6  => {
                active => 'false',                    # default
                start  => 'fd00:dead:beef:55::100',
                end    => 'fd00:dead:beef:55::1ff',
            },
            staticrouteipv6 => {
                active => 'false',                    # default
                tonet  => '',
                viagw  => '',
            },
        },
        vnet => {
            isolatedvnet => {
                active => 'true',
            },
            fwdphysical => {
                active      => 'false',               # default
                destination => 'any',                 # any/select dev; OTHER THAN ANY IS NOT SUPPORTED YET FIXME
                mode        => 'nat',                 # NAT/Routed
            },
        },
        ipv6routing   => 'false',                     # default
        DNSdomainname => '',                          # no value
    };
    # create the net step by step
    go_for_vnet($vnet);

    # Test a new network with IPV4
    $vnet->{name}                  = 'ipv4test';
    $vnet->{ipv4}{active}          = 'true';
    $vnet->{ipv4}{network}         = '10.0.1.0/24';
    $vnet->{ipv4}{dhcpv4}{active}  = 'true';
    $vnet->{ipv4}{dhcpv4}{start}   = '10.0.1.200';
    $vnet->{ipv4}{dhcpv4}{end}     = '10.0.1.220';
    $vnet->{ipv4}{staticrouteipv4} = 'false';
    $vnet->{ipv6}{active}          = 'false';
    # we have already an isolated network, we need a fwd physical now
    $vnet->{vnet}{isolatedvnet}{active}     = 'false';
    $vnet->{vnet}{fwdphysical}{active}      = 'true';
    $vnet->{vnet}{fwdphysical}{destination} = 'any';
    $vnet->{vnet}{fwdphysical}{mode}        = 'nat';
    $vnet->{vnet}{ipv6routing}              = 'false';
    go_for_vnet($vnet);

    # Test a new network with IPV6
    $vnet->{name} = 'ipv6test';
    # disable all IPV4
    $vnet->{ipv4}{active}          = 'false';
    $vnet->{ipv4}{dhcpv4}{active}  = 'false';
    $vnet->{ipv4}{staticrouteipv4} = 'false';
    $vnet->{ipv6}{active}          = 'true';
    $vnet->{ipv6}{network}         = 'fd00:dead:beef:55::/64';
    $vnet->{ipv6}{dhcpv6}{active}  = 'true';
    # we have already an isolated network, we need a fwd physical now
    $vnet->{vnet}{isolatedvnet}{active}     = 'false';
    $vnet->{vnet}{fwdphysical}{active}      = 'true';
    $vnet->{vnet}{fwdphysical}{destination} = 'any';
    $vnet->{vnet}{fwdphysical}{mode}        = 'routed';
    $vnet->{vnet}{ipv6routing}              = 'true';
    go_for_vnet($vnet);


    my @tocheck = ('vnettest', 'ipv4test', 'ipv6test');
    checking_vnet_result(\@tocheck);
}

1;

