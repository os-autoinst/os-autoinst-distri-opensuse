# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openvswitch iputils
# Summary: Basic openvswitch test
#
#   This test does the following
#    - Installs openvswitch
#    - Starts the systemd service unit
#    - Executes a few basic openvswitch commands
#    - Makes use of network namespaces and OpenFlow rules to test basic
#    connectivity between veth pairs and OvS switches connected via
#    patch ports.
#
# Maintainer: Markos Chandras <mchandras@suse.de>

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils qw(is_sle);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    my $pkg_name = 'openvswitch';
    # package openvswitch-switch still exist for sle12-sp2
    $pkg_name = 'openvswitch-switch' if is_sle('=12-sp2');

    zypper_call("in $pkg_name iputils", timeout => 300);

    # Start the openvswitch daemon
    systemctl 'start openvswitch', timeout => 200;

    # Make sure that basic commands work fine
    assert_script_run "ovs-vsctl add-br ovs-openqa-br0";
    assert_script_run "ovs-vsctl set-fail-mode ovs-openqa-br0 standalone";
    assert_script_run "ovs-vsctl get-fail-mode ovs-openqa-br0 | grep standalone";
    assert_script_run "ovs-vsctl show";
    assert_script_run "ovs-vsctl del-br ovs-openqa-br0";

    #
    # Create two bridges and connect them using patch ports. Then create 2 veth
    # pairs and connect one end of the first pair to the first bridge and one
    # end of the other pair to the other bridge. Finally, move the remaining
    # ends to two separate namespaces and check connectivity. The concept is
    # illustrated below:
    #
    #     ovs-openqa-ns0 NS                                            ovs-openqa-ns1 NS
    #     +---------------+                                            +---------------+
    #     | +-----------+ |                                            | +-----------+ |
    #     | | ovs-veth0 | |                                            | | ovs-veth1 | |
    #     | +-----------+ |                                            | +-----------+ |
    #     +-------^-------+                                            +--------^------+
    #             |                                                             |
    #             |          ovs-openqa-br0                ovs-openqa-br1       |
    #             |     ------------------------      ------------------------  |
    #             +---> ovs-veth-br0 | patch-br1 <--> patch-br0 | ovs-veth-br1 <+
    #                   ------------------------      ------------------------
    #
    assert_script_run "ovs-vsctl add-br ovs-openqa-br0";
    assert_script_run "ovs-vsctl add-br ovs-openqa-br1";

    assert_script_run "ovs-vsctl add-port ovs-openqa-br0 patch-br1 -- set interface patch-br1 type=patch options:peer=patch-br0";
    assert_script_run "ovs-vsctl add-port ovs-openqa-br1 patch-br0 -- set interface patch-br0 type=patch options:peer=patch-br1";

    script_run "ip link add ovs-veth0 type veth peer name ovs-veth-br0";
    script_run "ip link add ovs-veth1 type veth peer name ovs-veth-br1";

    assert_script_run "ovs-vsctl add-port ovs-openqa-br0 ovs-veth-br0";
    assert_script_run "ovs-vsctl add-port ovs-openqa-br1 ovs-veth-br1";

    script_run "ip netns add ovs-openqa-ns0";
    script_run "ip netns add ovs-openqa-ns1";
    script_run "ip link set ovs-veth0 netns ovs-openqa-ns0";
    script_run "ip link set ovs-veth1 netns ovs-openqa-ns1";
    script_run "ip netns exec ovs-openqa-ns0 ip addr add 172.16.0.1/24 dev ovs-veth0";
    script_run "ip netns exec ovs-openqa-ns1 ip addr add 172.16.0.2/24 dev ovs-veth1";
    # All up!
    script_run "ip netns exec ovs-openqa-ns0 ip link set dev ovs-veth0 up";
    script_run "ip netns exec ovs-openqa-ns1 ip link set dev ovs-veth1 up";
    script_run "ip link set dev ovs-veth-br0 up";
    script_run "ip link set dev ovs-veth-br1 up";
    # For debug purposes
    script_run "ovs-vsctl show";

    # Traffic should work now
    assert_script_run "ip netns exec ovs-openqa-ns0 ping -c 5 172.16.0.2", 30;

    # Lets render ovs-openqa-br0 useless
    script_run "ovs-ofctl del-flows ovs-openqa-br0";
    assert_script_run "! ip netns exec ovs-openqa-ns0 ping -c 5 172.16.0.2";

    # Add the L2 rule again and check that traffic is back
    script_run "ovs-ofctl add-flow ovs-openqa-br0 priority=0,actions=normal";
    assert_script_run "ip netns exec ovs-openqa-ns0 ping -c 5 172.16.0.2", 30;

    # teardown
    assert_script_run "ip netns del ovs-openqa-ns1";
    assert_script_run "ip netns del ovs-openqa-ns0";
    assert_script_run "ovs-vsctl del-br ovs-openqa-br1";
    assert_script_run "ovs-vsctl del-br ovs-openqa-br0";
    systemctl 'stop openvswitch';
}

1;
