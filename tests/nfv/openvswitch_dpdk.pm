# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: openvswitch installation and CLI test
#
#   This test does the following
#    - Installs openvswitch, qemu and dpdk
#    - Clones dpdk repo that is needed for vsperf
#    - Starts the systemd service unit
#    - Executes a few basic openvswitch commands
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

use base "consoletest";
use testapi;
use strict;
use utils;


sub run {
    my $dpdk_repo = "http://dpdk.org/git/dpdk";

    select_console 'root-console';

    zypper_call('in openvswitch-switch dpdk qemu git-core', timeout => 200);

    # Clone repositories
    assert_script_run "git clone $dpdk_repo";

    # Start the openvswitch daemon
    assert_script_run "systemctl start openvswitch", 200;

    # Make sure that basic commands work fine
    assert_script_run "ovs-vsctl add-br ovs-openqa-br0";
    assert_script_run "ovs-vsctl set-fail-mode ovs-openqa-br0 standalone";
    assert_script_run "ovs-vsctl get-fail-mode ovs-openqa-br0 | grep standalone";
    assert_script_run "ovs-vsctl show";
    assert_script_run "ovs-vsctl del-br ovs-openqa-br0";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
