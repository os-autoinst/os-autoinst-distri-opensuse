# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: openvswitch installation and CLI test
#
#   This test does the following
#    - Installs needed packages (ovs, dpdk, git, ...)
#    - Clones vsperf repository
#    - Starts the systemd service unit
#    - Executes a few basic openvswitch commands
#    - Removes the lines to skip OVS, DPDK and QEMU compilation
#    - Installs vsperf tool
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use strict;
use warnings;
use utils;
use lockapi;
use mmapi;
use version_utils 'is_sle';

sub get_trafficgen_ip {
    my $host1 = get_required_var('NFVTEST_IP1');
    my $host2 = get_required_var('NFVTEST_IP2');
    my $my_ip = script_output(q(ip -4 addr show eth0 | grep -E inet|awk '{print $2}'|cut -d/ -f1));
    return $host2 if ($my_ip eq $host1);
    return $host1;
}

sub run {
    my ($self) = @_;
    my $vsperf_repo = "https://gerrit.opnfv.org/gerrit/vswitchperf";
    my $vsperf_version = get_required_var('VSPERF_VERSION');
    my $vnf_image = get_required_var('VNF_IMAGE');
    my $trafficgen_ip = get_trafficgen_ip();
    my $children = get_children();
    my $child_id = (keys %$children)[0];

    select_serial_terminal;
    record_info("INFO", "Install needed packages for NFV tests: OVS, DPKD, QEMU");
    zypper_call('--quiet in git-core openvswitch-switch dpdk dpdk-tools qemu tcpdump', timeout => 60 * 4);

    assert_script_run("cd /root/");
    record_info("INFO", "Clone VSPerf repository");
    assert_script_run("git clone --quiet --depth 1 --branch $vsperf_version $vsperf_repo", timeout => 60 * 4);


    record_info("INFO", "Start openvswitch service");
    systemctl 'enable openvswitch', timeout => 60 * 2;
    systemctl 'start openvswitch', timeout => 60 * 2;

    record_info("INFO", "VSPerf Installation");
    assert_script_run("cd vswitchperf/systems");

    # Hack to skip the OVS, DPDK and QEMU compilation as we will use the vanilla packages
    assert_script_run("sed -n -e :a -e '1,8!{P;N;D;};N;ba' -i build_base_machine.sh");
    if (is_sle('>=15')) {
        assert_script_run("cp -r sles/15 sles/15.1") if (check_var('VERSION', '15-SP1'));
        assert_script_run("bash -x build_base_machine.sh", timeout => 60 * 10);
        zypper_call('--quiet in python2-pip');
    }
    elsif (check_var('VERSION', '12-SP4')) {
        assert_script_run("curl " . data_url('nfv/sles/12.4/build_base_machine.sh') . " -o /root/build_base_machine.sh");
        assert_script_run("chmod 755 /root/build_base_machine.sh");
        assert_script_run("bash -x /root/build_base_machine.sh", timeout => 60 * 10);
    }
    else {
        die "OS VERSION not supported. Available only on >=15 and 12-SP4";
    }
    assert_script_run("pip2 install -q requests");

    # Download VNF from OPNFV artifacts repository
    assert_script_run("wget $vnf_image -O /tmp/vloop-vnf.qcow2", timeout => 60 * 30);

    # Clone Trex repo inside VSPerf directories
    record_info("INFO", "Clone TREX repository");
    assert_script_run("cd /root/vswitchperf/src/trex; make", timeout => 60 * 30);

    # Copy VSPERF custom configuration files
    record_info("INFO", "Copy VSPERF config files to target directory");
    assert_script_run("curl " . data_url('nfv/conf/00_common.conf') . " -o /root/vswitchperf/conf/00_common.conf");
    assert_script_run("curl " . data_url('nfv/conf/01_testcases.conf') . " -o /root/vswitchperf/conf/01_testcases.conf");
    assert_script_run("curl " . data_url('nfv/conf/02_vswitch.conf') . " -o /root/vswitchperf/conf/02_vswitch.conf");
    assert_script_run("curl " . data_url('nfv/conf/03_traffic.conf') . " -o /root/vswitchperf/conf/03_traffic.conf");
    assert_script_run("curl " . data_url('nfv/conf/04_vnf.conf') . " -o /root/vswitchperf/conf/04_vnf.conf");
    assert_script_run("curl " . data_url('nfv/conf/05_collector.conf') . " -o /root/vswitchperf/conf/05_collector.conf");
    assert_script_run("curl " . data_url('nfv/conf/06_pktfwd.conf') . " -o /root/vswitchperf/conf/06_pktfwd.conf");
    assert_script_run("curl " . data_url('nfv/conf/07_loadgen.conf') . " -o /root/vswitchperf/conf/07_loadgen.conf");
    assert_script_run("curl " . data_url('nfv/conf/08_llcmanagement.conf') . " -o /root/vswitchperf/conf/08_llcmanagement.conf");
    assert_script_run("curl " . data_url('nfv/conf/10_custom.conf') . " -o /root/vswitchperf/conf/10_custom.conf");
    assert_script_run("sed -i 's/trafficgen_ip/$trafficgen_ip/' -i /root/vswitchperf/conf/10_custom.conf");

    record_info("INFO", "Wait for mutex NFV_TRAFFICGEN_READY");
    mutex_wait('NFV_TRAFFICGEN_READY', $child_id);

    if (is_ipmi) {
        # Generate ssh keypair and ssh-copy-id to the Traffic generator machine
        record_info("INFO", "Grant SSH access to trafficgen machine $trafficgen_ip");
        assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');
        exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$trafficgen_ip");

        # Bring mellanox interfaces up
        record_info("INFO", "Bring Mellanox interfaces up");
        assert_script_run("ip link set dev eth2 up");
        assert_script_run("ip link set dev eth3 up");
    }

    record_info("INFO", "Stop Firewall");
    systemctl 'stop ' . $self->firewall;

    record_info("INFO", "Installation ready. Mutex NFV_VSPERF_READY created");
    mutex_create("NFV_VSPERF_READY");
}

sub test_flags {
    return {fatal => 1};
}

1;
