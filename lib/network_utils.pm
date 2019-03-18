# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Functional methods to operate on network
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
package network_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(setup_static_network recover_network can_upload_logs iface ifc_exists);

=head2 setup_static_network
Configure static IP on SUT with setting up default GW.
Also doing test ping to 10.0.2.2 to check that network is alive
Set DNS server defined via required variable C<STATIC_DNS_SERVER>
=cut
sub setup_static_network {
    my (%args) = @_;
    # Set default values
    $args{ip} ||= '10.0.2.15';
    $args{gw} ||= testapi::host_ip();
    my $dns_ip = get_required_var('STATIC_DNS_SERVER');
    assert_script_run('echo default ' . $args{gw} . ' - - > /etc/sysconfig/network/routes');
    assert_script_run('echo "NETCONFIG_DNS_STATIC_SERVERS=' . $dns_ip . '" >> /etc/sysconfig/network/config');
    my $iface = iface();
    assert_script_run qq(echo -e "\\nSTARTMODE='auto'\\nBOOTPROTO='static'\\nIPADDR='$args{ip}'">/etc/sysconfig/network/ifcfg-$iface);
    assert_script_run 'rcnetwork restart';
    assert_script_run 'ip addr';
    assert_script_run 'ping -c 1 ' . $args{gw} . '|| journalctl -b --no-pager > /dev/' . $serialdev;
}

=head2 iface
    return first NIC which is not loopback
=cut
sub iface {
    return script_output('ls /sys/class/net/ | grep -v lo | head -1');
}

=head2 can_upload_logs
Returns if can ping worker host gateway
=cut
sub can_upload_logs {
    my ($gw) = @_;
    $gw ||= testapi::host_ip();
    return (script_run('ping -c 1 ' . $gw) == 0);
}

=head2 check_and_recover_network
Recover network with static config if is feasible, returns if can ping GW
Main use case is post_fail_hook, to be able to upload logs
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

sub ifc_exists {
    my ($ifc) = @_;
    return !script_run('ip link show dev ' . $ifc);
}

1;
