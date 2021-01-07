# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functions for testing openvswitch
# Maintainer: Anna Minou <anna.minou@suse.de>
#
package console::ovs_utils;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
# use utils;
use strict;
use warnings;

our @EXPORT = qw(add_bridge ping_check);

sub add_bridge {
    my $ip = shift;
    assert_script_run("ovs-vsctl add-br br-ipsec");
    assert_script_run("ip addr add $ip/24 dev br-ipsec");
    assert_script_run("ip link set br-ipsec up");
}

sub ping_check {
    my $server_ip = shift;
    my $client_ip = shift;
    my $vpn       = shift;
    assert_script_run("cd");
    assert_script_run "(ping -c 20 $vpn &>/dev/null &)";
    if ($vpn eq "192.0.0.2") {
        assert_script_run("tcpdump -ni any net -c 10 $client_ip > check.log");
        assert_script_run("grep 'IP $server_ip > $client_ip: ESP' check.log");
    }
    else {
        assert_script_run("tcpdump -ni any net -c 10 $server_ip > check.log");
        assert_script_run("grep 'IP $client_ip > $server_ip: ESP' check.log");
    }
    assert_script_run("pkill ping");
    assert_script_run("ping -c 5 $vpn");
    assert_script_run("rm check.log");
}
1;
