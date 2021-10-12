# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Run 'audit-remote-libvirt' test case of 'audit-test' test suite
# Maintainer: llzhao <llzhao@suse.com>
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
    zypper_call("in qemu libvirt virt-install virt-manager");

    # Start libvirtd daemon and start the default libvirt network
    assert_script_run("systemctl start libvirtd");
    assert_script_run("virsh net-start default");
    assert_script_run("systemctl is-active libvirtd");
    assert_script_run("virsh net-list | grep default | grep active");

    # Download the pre-installed guest images and sample xml files
    my $vm_name = 'vm-swtpm-legacy';
    my $hdd_1 = get_required_var('HDD_1');
    my $legacy_image = 'swtpm_legacy@64bit.qcow2';
    assert_script_run("wget -c -P $image_path " . autoinst_url("/assets/hdd/$hdd_1"), 900);
    assert_script_run("mv $image_path/$hdd_1 $image_path/$legacy_image");
    assert_script_run("wget --quiet " . data_url("swtpm/swtpm_legacy.xml") . " -P $image_path");

    # Define the guest vm and start it
    assert_script_run("cd $image_path");
    assert_script_run('virsh define swtpm_legacy.xml');
    assert_script_run("virsh start $vm_name");

    # Export AUDIT_TEST_REMOTE_VM
    assert_script_run("export AUDIT_TEST_REMOTE_VM=$vm_name");
    # Export AUGROK
    assert_script_run("export AUGROK=$audit_test::test_dir/audit-test/utils/augrok");

    # Run test case
    run_testcase('audit-remote-libvirt', make => 0, timeout => 120);

    # Compare current test results with baseline
    my $result = compare_run_log('audit_remote_libvirt');
    $self->result($result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
