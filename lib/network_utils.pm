# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Functional methods to operate on network
# Maintainer: Rodion Iafarov <riafarov@suse.com>
package network_utils;

use base Exporter;
use Exporter;

use strict;

our @EXPORT = qw(setup_static_network check_and_recover_network);

use testapi;

=head2 setup_static_network
Configure static IP on SUT with setting up default GW.
Also doing test ping to 10.0.2.2 to check that network is alive
=cut
sub setup_static_network {
    my ($ip) = @_;
    assert_script_run("echo 'default 10.0.2.2 - -' > /etc/sysconfig/network/routes");
    assert_script_run("echo 'nameserver 10.160.0.1' >> /etc/resolv.conf");
    my $iface = script_output('ls /sys/class/net/ | grep -v lo | head -1');
    assert_script_run qq(echo -e "\\nSTARTMODE='auto'\\nBOOTPROTO='static'\\nIPADDR='$ip'">/etc/sysconfig/network/ifcfg-$iface);
    assert_script_run "rcnetwork restart";
    assert_script_run "ip addr";
    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager > /dev/$serialdev";
}

1;
