# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>

package meltdown;
use base "Mitigation";
use bootloader_setup;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;

our $mitigations_list =
  {
    name => "meltdown",
    CPUID => hex '20000000',
    IA32_ARCH_CAPABILITIES => 1,    #bit0 -- RDCL_NO
    parameter => 'pti',
    cpuflags => ['pti'],
    sysfs_name => "meltdown",
    sysfs => {
        on => "Mitigation: PTI",
        off => "Vulnerable",
        auto => "Mitigation: PTI",
        default => "Mitigation: PTI",
    },
    dmesg => {
        on => "Kernel/User page tables isolation: enabled",
        off => "",
        auto => "Kernel/User page tables isolation: enabled",
        default => "Kernel/User page tables isolation: enabled",
    },
    cmdline => [
        "on",
        "off",
        "auto",
    ],
    lscpu => {
        on => "pti",
        off => "",
        auto => "pti",
    },
  };

sub new {
    my ($class, $args) = @_;
    #Help constructor distinguishing is our own test object or openQA call
    if ($args eq $mitigations_list) {
        return bless $args, $class;
    }
    my $self = $class->SUPER::new($args);
    return $self;
}
#
#Override Mitigation::check_cpu_flags
#When meltdown=off, pti flag disappear.
sub check_cpu_flags {
    my ($self, $cmd) = @_;
    assert_script_run('cat /proc/cpuinfo');
    foreach my $flag (@{$self->{cpuflags}}) {
        #switch off a feature, it will not be displayed in 'flags'
        if ($cmd eq "off") {
            die "switch off but it display" unless script_run('cat /proc/cpuinfo | grep "^flags.*' . $flag . '.*"');
        } else {
            assert_script_run('cat /proc/cpuinfo | grep "^flags.*' . $flag . '.*"');
        }
    }
}
sub run {
    my ($self) = shift;
    my $obj = meltdown->new($mitigations_list);
    #run base function testing
    my $ret = $obj->do_test();
    if ($ret ne 2) {
        #extra testing for nopti
        add_grub_cmdline_settings("nopti");
        update_grub_and_reboot($self, 150);
        assert_script_run('cat /proc/cmdline | grep "nopti" ');
        assert_script_run('cat /proc/cpuinfo | grep -L "pti"');
        assert_script_run('cat /sys/devices/system/cpu/vulnerabilities/meltdown | grep -q "Vulnerable" ');
        assert_script_run('dmesg | grep "Kernel/User page tables isolation: disabled on command line" ');
        remove_grub_cmdline_settings("nopti");
        grub_mkconfig;
    }
}

sub update_grub_and_reboot {
    my ($self, $timeout) = @_;
    grub_mkconfig;
    Mitigation::reboot_and_wait($self, $timeout);
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('pti=[a-z,]*');
    remove_grub_cmdline_settings("nopti");
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
