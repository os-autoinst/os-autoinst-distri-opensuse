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
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed is_leap is_opensuse);
use Utils::Architectures qw(is_x86_64 is_aarch64);
use bootloader_setup qw(change_grub_config);
use power_action_utils 'power_action';
use network_utils 'iface';

sub install_ovs_dpdk {
    if (is_sle('=15-sp5') || (is_leap('=15.5') && !(check_var('FLAVOR', 'DVD-Updates')))) {
        zypper_call('in openvswitch3 dpdk22 dpdk22-tools', timeout => 300);
    }
    else {
        zypper_call('in openvswitch dpdk dpdk-tools', timeout => 300);
    }
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
    script_run 'ip a > /tmp/network-device.log';    # need details of network device if something goes wrong
    script_run 'cnf dpdk-hugepages.py' if (is_leap('>=15.5'));    # check wether dpdk-hugegapes is available on Leap 15.5, see boo#1212113
    assert_script_run 'modprobe "vfio-pci"';    # load required vfio-pci at first
    my $iface = iface();
    assert_script_run "dpdk_nic_bind -u $iface";

    record_info('dpdk-hugepages.py -s', script_output('dpdk-hugepages.py -s', proceed_on_failure => 1));
    record_info('dpdk-devbind.py -s', script_output('dpdk-devbind.py -s', proceed_on_failure => 1));
    my $pci_bus = script_output(q(dpdk-devbind.py  --status-dev net | grep "unused=vfio-pci" | awk '{ print $1 }' | head -n1));
    assert_script_run("dpdk-devbind.py -b vfio-pci $pci_bus");
}

sub test_ovs_dpdk {
    systemctl 'start ovsdb-server';
    script_output('systemctl is-active ovsdb-server', sub { m/active/ });
    systemctl 'start ovs-vswitchd';
    script_output('systemctl is-active ovs-vswitchd', sub { m/active/ });
    assert_script_run 'ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true';

    # check dpdk-init and version
    record_info('bsc#1205702') if script_output('ovs-vsctl get Open_vSwitch . dpdk_initialize', m/1 false/);
    script_output('ovs-vsctl get Open_vSwitch . dpdk_version', m/1 DPDK/);

    # check dpdk_nic_bind --status-dev net
    assert_script_run 'dpdk_nic_bind --status-dev net';

    # check dpdk-hugepages
    # we have issue with missing python script dpdk-hugepages.py, see boo#1212113
    assert_script_run 'which dpdk-hugepages.py' if (is_sle('>=15-sp5') || is_tumbleweed || (is_leap('>=15.5') && !(check_var('FLAVOR', 'DVD-Updates'))));
    assert_script_run 'grep -i  "dpdk enabled" /var/log/openvswitch/ovs-vswitchd.log';
}


sub run {

    my ($self) = @_;

    select_serial_terminal;
    # Enable IOMMU
    if (is_x86_64) {
        change_grub_config('=\"[^\"]*', '& iommu=pt intel_iommu=on)', 'GRUB_CMDLINE_LINUX_DEFAULT', '', 1);
        power_action('reboot', textmode => 1);
        $self->wait_boot;
        select_serial_terminal;
    }
    install_ovs_dpdk;
    setup_hugepages;
    return if (is_aarch64);
    load_bind_kernel_module;
    test_ovs_dpdk;
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    $self->SUPER::post_fail_hook;
    upload_logs('/var/log/openvswitch/ovs-vswitchd.log');
    upload_logs('/tmp/network-device.log');
}

1;

