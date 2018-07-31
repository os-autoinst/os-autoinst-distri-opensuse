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
use lockapi;
use mmapi;
use serial_terminal 'select_virtio_console';

sub run {
    my $vsperf_repo = "https://gerrit.opnfv.org/gerrit/vswitchperf";
    my $dpdk_repo   = "http://dpdk.org/git/dpdk";
    my $host1       = get_required_var('NFVTEST_IP1');
    my $host2       = get_required_var('NFVTEST_IP2');
    my $children    = get_children();
    my $child_id    = (keys %$children)[0];

    select_virtio_console();

    zypper_call('--quiet in git-core openvswitch-switch dpdk qemu tcpdump', timeout => 200);

    # Clone repositories
    assert_script_run("cd /root/");
    assert_script_run("git clone --quiet --depth 1 $vsperf_repo");
    assert_script_run("git clone --quiet --depth 1 $dpdk_repo");

    # Start the openvswitch daemon
    systemctl 'enable openvswitch', timeout => 200;
    systemctl 'start openvswitch',  timeout => 200;

    # VSPerf Installation
    assert_script_run("cd vswitchperf/systems");
    if (check_var('VERSION', '15')) {
        # Hack to skip the OVS, DPDK and QEMU compilation as we will use the vanilla packages
        assert_script_run("sed -n -e :a -e '1,8!{P;N;D;};N;ba' -i build_base_machine.sh");
        zypper_call('ar -f http://download.suse.de/ibs/SUSE:/SLE-12:/GA/standard/SUSE:SLE-12:GA.repo SLE-12-GA-REPO');
        assert_script_run("bash -x build_base_machine.sh", 300);
    }
    elsif (check_var('VERSION', '12-SP4')) {
        assert_script_run("curl " . data_url('nfv/sles/12.4/build_base_machine.sh') . " -o /root/build_base_machine.sh");
        assert_script_run("chmod 755 /root/build_base_machine.sh");
        assert_script_run("bash -x /root/build_base_machine.sh", timeout => 500);
    }
    else {
        die "OS VERSION not supported. Available only on 15 and 12-SP4";
    }
    assert_script_run("cd /root/vswitchperf/src/trex; make");

    # Setup ssh keys, wait until trafficgen machine is up and ready
    mutex_wait('NFV_trafficgen_ready', $child_id);
    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$host1");
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$host2");

    # Bring mellanox interfaces up
    assert_script_run("ip link set dev eth2 up");
    assert_script_run("ip link set dev eth2 up");

    mutex_create("NFV_testing_ready");
    wait_for_children;
}

sub test_flags {
    return {fatal => 1};
}

1;
