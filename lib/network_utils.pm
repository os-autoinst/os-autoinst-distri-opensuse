=head1 network_utils

Functional methods to operate on network

=cut
# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Functional methods to operate on network
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
package network_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use mm_network;

our @EXPORT = qw(setup_static_network recover_network can_upload_logs iface ifc_exists ifc_is_up genmac);

=head2 setup_static_network

 setup_static_network(ip => '10.0.2.15', gw => '10.0.2.1');

Configure static IP on SUT with setting up default GW.
Also doing test ping to 10.0.2.2 to check that network is alive
Set DNS server defined via required variable C<STATIC_DNS_SERVER>

=cut

sub setup_static_network {
    my (%args) = @_;
    # Set default values
    $args{ip} //= '10.0.2.15';
    $args{gw} //= testapi::host_ip();
    $args{silent} //= 0;
    configure_static_dns(get_host_resolv_conf(), silent => $args{silent});
    assert_script_run('echo default ' . $args{gw} . ' - - > /etc/sysconfig/network/routes');
    my $iface = iface();
    assert_script_run qq(echo -e "\\nSTARTMODE='auto'\\nBOOTPROTO='static'\\nIPADDR='$args{ip}'">/etc/sysconfig/network/ifcfg-$iface);
    assert_script_run 'rcnetwork restart';
    assert_script_run 'ip addr';
    assert_script_run 'ping -c 1 ' . $args{gw} . '|| journalctl -b --no-pager -o short-precise > /dev/' . $serialdev;
    assert_script_run('ip -6 addr add ' . $args{ipv6} . ' dev ' . $iface) if (exists($args{ipv6}));
}

=head2 iface

 iface([$quantity]);

Return first NIC which is not loopback

=cut

sub iface {
    my ($quantity) = @_;
    $quantity ||= 1;
    # bonding_masters showing up in ppc64le jobs in 15-SP5: bsc#1210641
    return script_output('ls /sys/class/net/ | grep -v lo | grep -v bonding_masters | head -' . $quantity);
}

=head2 can_upload_logs

 can_upload_logs([$gw]);

Returns if can ping worker host gateway
=cut

sub can_upload_logs {
    my ($gw) = @_;
    $gw ||= testapi::host_ip();
    return (script_run('ping -c 1 ' . $gw) == 0);
}


=head2 recover_network

 recover_network([ip => $ip] [, gw => $gw]);

Recover network with static config if is feasible, returns if can ping GW.
Main use case is post_fail_hook, to be able to upload logs.

Accepts following parameters :

C<ip> => allowing to specify certain IP which would be used for recovery
in case skiped '10.0.2.15/24' will be used as fallback.

C<gw> => allowing to specify default gateway. Fallback to worker IP in case nothing specified.
=cut

sub recover_network {
    my (%args) = @_;

    # We set static setup just to upload logs, so no permament setup
    # Set default values
    $args{ip} //= '10.0.2.15/24';
    $args{gw} //= testapi::host_ip();
    my $iface = iface();
    # Clean routes and ip address settings
    script_run "ip a flush dev $iface";
    script_run 'ip r flush all';
    # Set expected ip and routes and set interface up
    script_run "ip a a $args{ip} dev $iface";
    script_run "ip r a default via $args{gw} dev $iface";
    script_run "ip link set dev $iface up";
    # Display settings
    script_run 'ip a s';
    script_run 'ip r s';

    return can_upload_logs();
}

=head2 ifc_exists

 ifc_exists([$ifc]);

Return if ifconfig exists.

=cut

sub ifc_exists {
    my ($ifc) = @_;
    return !script_run('ip link show dev ' . $ifc);
}

=head2 ifc_is_up

 ifc_is_up([$ifc]);

Return only if network status is UP.

=cut

sub ifc_is_up {
    my ($ifc) = @_;
    return !script_run("ip link show dev $ifc | grep 'state UP'");
}

=head2 genmac

Generate custom MAC address.
Used for Xen domU testing, to define MAC address once for whole test suite lifecycle.

 genmac(['aa:bb:cc'])

=cut

sub genmac {
    my @mac = split(/:/, shift);
    my $len = scalar(@mac);
    for (my $i = 0; $i < (6 - $len); $i++) {
        push @mac, (sprintf("%02X", int(rand(254))));
    }
    return lc(join(':', @mac));
}

1;
