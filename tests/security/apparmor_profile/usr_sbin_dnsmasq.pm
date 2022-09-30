# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-utils nscd
# Summary: Test with "usr.sbin.dnsmasq" is in "enforce" mode and AppArmor is
#          "enabled && active", libvirt manages the NAT network depending on
#          dnsmasq have no error
# - Create virtual machines with libvirt in NAT network setting
# - Switch dnsmasq to enforce mode
# - Check network status of the guest machine(s)
# - Check audit.log for errors related to dnsmasq
# Maintainer: QE Security <none@suse.de>
# Tags: poo#103458, tc#1767545

use base 'apparmortest';
use strict;
use warnings;
use testapi;
use utils;

sub check_audit_log {
    my ($self) = shift;
    my $log_file = $apparmortest::audit_log;

    # Check audit log contains no related error
    my $script_output = script_output "cat $log_file";
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*dnsmasq.* comm=.*libvirt.*/sx) {
        record_info('ERROR', "There are errors found in $log_file", result => 'fail');
        $self->result('fail');
    }
    record_info("audit log:", "$script_output");
}

sub run {
    my ($self) = shift;
    my $log_file = $apparmortest::audit_log;
    my $result_file = '/tmp/result_file';
    my $image_path = '/var/lib/libvirt/images';

    select_console 'root-console';

    # Install the required packages for libvirt environment setup
    zypper_call('in qemu dnsmasq libvirt');

    # Check the version for "SLE-20353 QA: dnsmasq update to 2.83"
    my $current_ver = script_output('zypper se -s -i dnsmasq libnettle');
    record_info('Version', "$current_ver");

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
    assert_script_run('wget --quiet ' . data_url("cc/$vm_name.xml") . " -P $image_path");

    # Cleanup audit log
    assert_script_run("echo > $log_file");

    # Set the AppArmor security profile to enforce mode
    my $profile_name = 'usr.sbin.dnsmasq';
    validate_script_output("aa-enforce $profile_name", sub { m/Setting .*$profile_name to enforce mode./ });

    # Define/Start guest vm and restart libvirtd to generate audit records
    assert_script_run("cd $image_path");
    assert_script_run('systemctl restart libvirtd');
    assert_script_run("virsh define $vm_name.xml");
    assert_script_run("virsh start $vm_name");
    assert_script_run('systemctl restart libvirtd');
    assert_script_run('systemctl --no-pager status libvirtd');

    # Check audit log should contain no related error
    check_audit_log($self);

    # Cleanup audit log
    assert_script_run("echo > $log_file");

    # Run virsh to manage network to generate audit records
    assert_script_run('virsh net-destroy default');
    assert_script_run('virsh net-start default');
    assert_script_run('systemctl --no-pager status libvirtd');

    # Check audit log should contain no related error
    check_audit_log($self);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
