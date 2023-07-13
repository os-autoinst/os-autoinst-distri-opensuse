# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'audit-remote-libvirt' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#96531

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    my $image_path = '/var/lib/libvirt/images';
    select_console 'root-console';

    # Install the required packages for libvirt environment setup,
    zypper_call('in qemu libvirt virt-install virt-manager');

    # Start libvirtd daemon and start the default libvirt network
    assert_script_run('systemctl start libvirtd');
    assert_script_run('virsh net-define /etc/libvirt/qemu/networks/default.xml');
    assert_script_run('virsh net-start default');
    assert_script_run('systemctl is-active libvirtd');
    assert_script_run('virsh net-list | grep default | grep active');

    # Download the pre-installed guest images and sample xml files
    my $vm_name = 'nested-L2-vm';
    my $vm_L2 = get_required_var('HDD_L2');
    assert_script_run("wget -c -P $image_path " . autoinst_url("/assets/hdd/$vm_L2"), 900);
    assert_script_run("mv $image_path/$vm_L2 $image_path/$vm_name.qcow2");
    assert_script_run("wget --quiet " . data_url("cc/$vm_name.xml") . " -P $image_path");

    # Define the guest vm and start it
    assert_script_run("cd $image_path");
    assert_script_run("virsh define $vm_name.xml");
    assert_script_run("virsh start $vm_name");

    # Export AUDIT_TEST_REMOTE_VM
    assert_script_run("export AUDIT_TEST_REMOTE_VM=$vm_name");
    # Export AUGROK
    assert_script_run("export AUGROK=$audit_test::test_dir/audit-test/utils/augrok");

    # Run test case
    run_testcase('audit-remote-libvirt', make => 0, timeout => 120);

    # Compare current test results with baseline
    my $result = compare_run_log('audit-remote-libvirt');
    $self->result($result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
