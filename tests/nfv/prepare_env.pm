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
#    - Installs needed packages (ovs, dpdk, git, ...)
#    - Clones vsperf and dpdk repositories
#    - Starts the systemd service unit
#    - Executes a few basic openvswitch commands
#    - Removes the lines to skip OVS, DPDK and QEMU compilation
#    - Installs vsperf tool
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

use base "opensusebasetest";
use testapi;
use strict;
use utils;
use serial_terminal 'select_virtio_console';

sub run {
    my $vsperf_repo = "https://gerrit.opnfv.org/gerrit/vswitchperf";
    my $dpdk_repo   = "http://dpdk.org/git/dpdk";

    select_virtio_console();

    zypper_call('--quiet in git-core openvswitch-switch dpdk qemu tcpdump', timeout => 200);

    # Clone repositories
    assert_script_run("git clone --quiet --depth 1 $vsperf_repo");
    assert_script_run("git clone --quiet --depth 1 $dpdk_repo");

    # Start the openvswitch daemon
    systemctl 'start openvswitch', timeout => 200;

    # Make sure that basic OVS commands work
    assert_script_run("ovs-vsctl add-br ovs-openqa-br0");
    assert_script_run("ovs-vsctl set-fail-mode ovs-openqa-br0 standalone");
    assert_script_run("ovs-vsctl get-fail-mode ovs-openqa-br0 | grep standalone");
    assert_script_run("ovs-vsctl show");
    assert_script_run("ovs-vsctl del-br ovs-openqa-br0");

    # VSPerf Installation
    assert_script_run("cd vswitchperf/systems");
    # Hack to skip the OVS, DPDK and QEMU compilation as SLE15 will use the vanilla packages
    assert_script_run("sed -n -e :a -e '1,8!{P;N;D;};N;ba' -i build_base_machine.sh");
    assert_script_run("bash -x build_base_machine.sh", 300);
}

sub test_flags {
    return {fatal => 1};
}

1;

