# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
    my $vpn = shift;
    assert_script_run("cd");
    assert_script_run "(ping $vpn &>ping.log &)";
    if ($vpn eq "192.0.0.2") {
        assert_script_run("tcpdump -ni any net -c 20 $client_ip > check.log", 300);
        assert_script_run('cat check.log');
        assert_script_run("grep 'IP $server_ip > $client_ip: ESP' check.log");
    }
    else {
        assert_script_run("tcpdump -ni any net -c 20 $server_ip > check.log", 300);
        assert_script_run('cat check.log');
        assert_script_run("grep 'IP $client_ip > $server_ip: ESP' check.log");
    }
    assert_script_run("pkill ping");
    assert_script_run('cat ping.log');
    assert_script_run("rm ping.log check.log");
}
1;
