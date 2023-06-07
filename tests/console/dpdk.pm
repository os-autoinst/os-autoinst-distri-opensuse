# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: functional test of DPDK with Open vSwitch
#
#   This test does the following
#    - install openvswitch3*, dpdk packages and related tools
#    - configure hugepages and bind kernel module vfio or uio_pci_generaic on NIC
#    - verify ovsdb-server and ovs-vswitchd
#    - check dpdk-hugepages
#
# Notice:  some dpdk test cannot be excuted because of limitation on qemu vm:
#    - run dpdk-testpmd  (we get error like 'EAL FATAL; unsupported cpu type' on qemu, this is different than on physical machine and requires a different setup)
#    - systemctl 'restart ovs-vswitchd' (failed at moment, assume that is related to unsuccessful binding of kernel module to network device)
#
# Maintainer: Zaoliang Luo <zluo@suse.de>, qe-core team SUSE

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;


sub install_ovs_dpdk {
    zypper_call('in openvswitch3 dpdk22 dpdk22-tools', timeout => 300);
    # export PATH for later usage
    assert_script_run 'export PATH=$PATH:/usr/share/openvswitch/scripts';
}

sub setup_hugepages {
    script_run 'sysctl -w vm.nr_hugepages=2';    # set up run-time allocation of huge pages
    script_run 'grep HugePages_ /proc/meminfo';
    script_run 'mount -t hugetlbfs none /dev/hugepages';    # mount the hugepages
}

sub load_bind_kernel_module {
    # find out network device which is up and running, in most case it is 'eth0'
    # but this is not possible to hand over to python script used for binding kernel module by assert_script_run 'dpdk_nic_bind -u "$NIC"'
    # keep following code for open suggestion, will remove $cmd lines later

    my $cmd = <<EOF;
ip a | grep -i 'br0 state UP' | awk '{print \$2}' | sed -e 's/://'
EOF
    assert_script_run 'modprobe "vfio-pci"';    # load required vfio-pci at first
    assert_script_run 'dpdk_nic_bind -u eth0';    # unbind the device 'eth0' at first
    record_soft_failure 'bsc#1205702, cannot bind to network device: dpdk_nic_bind --bind=vfio-pci eth0' unless assert_script_run 'dpdk_nic_bind --bind="vfio-pci" 0000:00:04.0'; # bind vfio-pci
}

sub test_ovs_dpdk {
    systemctl 'start ovsdb-server';
    script_output('systemctl is-active ovsdb-server', sub { m/active/ });
    systemctl 'start ovs-vswitchd';
    script_output('systemctl is-active ovs-vswitchd', sub { m/active/ });
    assert_script_run 'ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true';

    # check dpdk-init and version
    record_soft_failure 'dpdk could not be initialized, it is related to issue bsc#1205702' if script_output('ovs-vsctl get Open_vSwitch . dpdk_initialize', m/1 false/);
    script_output('ovs-vsctl get Open_vSwitch . dpdk_version', m/1 DPDK/);

    # check dpdk_nic_bind --status-dev net
    assert_script_run 'dpdk_nic_bind --status-dev net';

    # check dpdk-hugenpages
    assert_script_run 'dpdk-hugepages.py -s';
    assert_script_run 'grep -i  "dpdk enabled" /var/log/openvswitch/ovs-vswitchd.log';
}


sub run {

    my ($self) = @_;
    select_serial_terminal;
    install_ovs_dpdk;
    setup_hugepages;
    load_bind_kernel_module;
    test_ovs_dpdk;
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    $self->SUPER::post_fail_hook;
    upload_logs('/var/log/openvswitch/ovs-vswitchd.log');
}

1;

