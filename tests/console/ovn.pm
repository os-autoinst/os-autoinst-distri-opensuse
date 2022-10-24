# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openvswitch ovn ovn-central ovn-devel ovn-docker ovn-host ovn-vtep
# iproute2
# Summary: Basic OVN (Open Virtual Network) test
#
#   This test does the following
#    - Installs ovn
#    - Starts the required services
#    - Sets up a basic topology consisting of one logical switch and
#        two logical ports attached to it
#    - Makes use of network namespaces to test basic
#        connectivity between the ports
#
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use version_utils 'is_tumbleweed';


sub run {
    select_serial_terminal;

    zypper_call('in openvswitch ovn ovn-central ovn-devel ovn-docker ovn-host ovn-vtep', timeout => 300);

    # Start the openvswitch and OVN daemons
    systemctl 'start openvswitch ovn-controller ovn-northd', timeout => 200;

    assert_script_run "ovn-sbctl set-connection ptcp:6642";

    my $ovn_encap_ip = "";
    if (is_tumbleweed) {
        $ovn_encap_ip = script_output(q(ip address | awk '/inet/ && /\/24/ { split($2, ip, "/"); print ip[1] }'));
    }
    else {
        $ovn_encap_ip = script_output(q(ip -4 address show eth0 | awk '/inet/ { split($2, ip, "/"); print ip[1] }'));
    }
    my $hostname = script_output "hostname";

    assert_script_run "ovs-vsctl set open_vswitch . external_ids:ovn-remote=tcp:localhost:6642  external_ids:ovn-encap-ip=$ovn_encap_ip external_ids:ovn-encap-type=geneve external_ids:system-id=$hostname";

    # Create test environment
    assert_script_run "ovn-nbctl ls-add network1";
    assert_script_run "ovn-nbctl lsp-add network1 vm1";
    assert_script_run "ovn-nbctl lsp-add network1 vm2";
    assert_script_run "ovn-nbctl lsp-set-addresses vm1 '40:44:00:00:00:01 192.168.200.21'";
    assert_script_run "ovn-nbctl lsp-set-addresses vm2 '40:44:00:00:00:02 192.168.200.22'";

    assert_script_run "ovn-nbctl show";

    assert_script_run "ovs-vsctl add-port br-int vm1 -- set Interface vm1 type=internal -- set Interface vm1 external_ids:iface-id=vm1";
    assert_script_run "ovs-vsctl add-port br-int vm2 -- set Interface vm2 type=internal -- set Interface vm2 external_ids:iface-id=vm2";

    assert_script_run "ip netns add vm1";
    assert_script_run "ip link set vm1 netns vm1";
    assert_script_run "ip netns exec vm1 ip link set vm1 address 40:44:00:00:00:01";
    assert_script_run "ip netns exec vm1 ip addr add 192.168.200.21/24 dev vm1";
    assert_script_run "ip netns exec vm1 ip link set vm1 up";
    assert_script_run "ip netns add vm2";
    assert_script_run "ip link set vm2 netns vm2";
    assert_script_run "ip netns exec vm2 ip link set vm2 address 40:44:00:00:00:02";
    assert_script_run "ip netns exec vm2 ip addr add 192.168.200.22/24 dev vm2";
    assert_script_run "ip netns exec vm2 ip link set vm2 up";

    # show some info for debug purposes
    assert_script_run "ip netns list";
    assert_script_run "ip netns exec vm1 ip addr";
    assert_script_run "ip netns exec vm2 ip addr";

    # check connectivity
    assert_script_run "ip netns exec vm1 ping -c2 192.168.200.22";
    assert_script_run "ip netns exec vm2 ping -c2 192.168.200.21";

    # teardown
    assert_script_run 'ip netns del vm2';
    assert_script_run 'ip netns del vm1';
    assert_script_run 'ovs-vsctl del-br br-int';
    systemctl 'stop openvswitch ovn-controller ovn-northd', timeout => 200;
}

1;
