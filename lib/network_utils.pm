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
use testapi;

our @EXPORT = qw(setup_static_network recover_network can_upload_logs iface);

our $default_gw = '10.0.2.2';

=head2 setup_static_network
Configure static IP on SUT with setting up default GW.
Also doing test ping to 10.0.2.2 to check that network is alive
=cut
sub setup_static_network {
    my (%args) = @_;
    # Set default values
    $args{ip} ||= '10.0.2.15';
    $args{gw} ||= $default_gw;
    assert_script_run('echo default ' . $args{gw} . ' - - > /etc/sysconfig/network/routes');
    assert_script_run('echo "nameserver 10.160.0.1" >> /etc/resolv.conf');
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
    $gw ||= $default_gw;
    return script_run('ping -c 1 ' . $default_gw);
}

=head2 check_and_recover_network
Recover network with static config if is feasible, returns if can ping GW
=cut
sub recover_network {
    setup_static_network(gw => testapi::host_ip());
    return can_upload_logs;
}

1;
