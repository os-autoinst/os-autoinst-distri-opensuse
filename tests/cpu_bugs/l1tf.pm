# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>

use strict;
use warnings;

use base "consoletest";
use bootloader_setup;
use strict;
use testapi;
use utils;
use power_action_utils 'power_action';

use Mitigation;

my %mitigations_list =
  (
    name                   => "l1tf",
    CPUID                  => hex '10000000',
    IA32_ARCH_CAPABILITIES => 8,                #bit3 --SKIP_L1TF_VMENTRY
    parameter              => 'l1tf',
    cpuflags               => ['flush_l1d'],
    sysfs_name             => "l1tf",
    sysfs                  => {
        full         => "Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled",
        full_force   => "Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled",
        flush        => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable",
        flush_nosmt  => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled",
        flush_nowarn => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable",
        off          => "Mitigation: PTE Inversion; VMX: vulnerable",
        default      => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable",
    },
    cmdline => [
        "full",
        "full,force",
        "flush",
        "flush,nosmt",
        "flush,nowarn",
        "off",
    ],
  );


sub run {
    my $self = shift;
    if (check_var('BACKEND', 'qemu')) {
        record_info('softfail', "QEMU needn't run this testcase");
        return;
    }
    my $obj = Mitigation->new(\%mitigations_list);
    #run base function testing
    my $ret = $obj->do_test();
    if ($ret ne 2) {
        assert_script_run('cat /sys/devices/system/cpu/smt/active | grep "1"');
        assert_script_run('echo off>/sys/devices/system/cpu/smt/control');
        assert_script_run('lscpu | grep "Off-line CPU(s) list"');
        assert_script_run('cat /sys/devices/system/cpu/smt/active | grep "0"');
        add_grub_cmdline_settings("l1tf=full,force");
        update_grub_and_reboot($self, 150);
        assert_script_run('lscpu | grep "Off-line CPU(s) list"');
        assert_script_run('cat /sys/devices/system/cpu/smt/active | grep "0"');
        assert_script_run('cat /sys/devices/system/cpu/smt/control | grep "forceoff"');
        die "Control cannot be modified under the mode of forceoff" unless script_run('echo on>/sys/devices/system/cpu/smt/control');
        assert_script_run('cat /sys/devices/system/cpu/smt/control | grep "forceoff"');
        remove_grub_cmdline_settings("l1tf=full,force");
        update_grub_and_reboot($self, 150);
        assert_script_run('cat /sys/module/kvm_intel/parameters/ept | grep "Y"');
        my $damn = script_run('modprobe -r kvm_intel | grep "kvm"');
        if ($damn eq 0) {
            record_info('fail', "Couldn't find kvm when removed the kvm_intel");
            die;
        }
        assert_script_run('modprobe kvm_intel ept=0;lsmod | grep "kvm"');
        check_param('/sys/module/kvm_intel/parameters/ept', "N");
        assert_script_run('cat /sys/devices/system/cpu/vulnerabilities/l1tf | grep "EPT disabled"');
    }
}

sub update_grub_and_reboot {
    my ($self, $timeout) = @_;
    grub_mkconfig;
    Mitigation::reboot_and_wait($self, $timeout);
}

sub check_param {
    my ($param, $value) = @_;
    assert_script_run("cat $param | grep $value");
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('l1tf=[a-z,]*');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
    $self->SUPER::post_fail_hook;
}

1;
