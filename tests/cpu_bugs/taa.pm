# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>

package taa;
use strict;
use warnings;
use base "Mitigation";
use bootloader_setup;
use ipmi_backend_utils;
use testapi;
use Utils::Backends;
use utils;

our $mitigations_list =
  {
    name => "taa",
    parameter => 'tsx_async_abort',
    CPUID => hex '800',    #CPUID.07h.EBX.RTM [bit 11]
    IA32_ARCH_CAPABILITIES => 256,    #bit8 TAA_NO
    sysfs_name => "tsx_async_abort",
    sysfs => {
        off => "Vulnerable",
        full => "Mitigation: Clear CPU buffers; SMT vulnerable",
        "full,nosmt" => "Mitigation: Clear CPU buffers; SMT disabled",
        default => "Mitigation: Clear CPU buffers; SMT vulnerable",
    },
    dmesg => {
        full => "TAA: Mitigation: Clear CPU buffers",
        off => "Vulnerable",
        "full,nosmt" => "TAA: Mitigation: Clear CPU buffers",
    },
    cmdline => [
        "full",
        "full,nosmt",
        "off",
    ],
  };
# Add icelake of vh018 information
if (get_var('MICRO_ARCHITECTURE', '') =~ /Icelake/) {
    $mitigations_list->{sysfs}->{off} = 'Not affected';
    $mitigations_list->{sysfs}->{full} = 'Not affected';
    $mitigations_list->{sysfs}->{"full,nosmt"} = 'Not affected';
    $mitigations_list->{sysfs}->{default} = 'Not affected';
}
sub new {
    my ($class, $args) = @_;
    #Help constructor distinguishing is our own test object or openQA call
    if ($args eq $mitigations_list) {
        return bless $args, $class;
    }
    my $self = $class->SUPER::new($args);
    return $self;
}

sub update_list_for_qemu {
    my ($self) = shift;
    $mitigations_list->{sysfs}->{full} =~ s/SMT vulnerable/SMT Host state unknown/ig;
    $mitigations_list->{sysfs}->{"full,nosmt"} =~ s/SMT disabled/SMT Host state unknown/ig;
    $mitigations_list->{sysfs}->{default} =~ s/SMT vulnerable/SMT Host state unknown/ig;
    if (get_var('MACHINE') =~ /^qemu-.*-NO-IBRS$/) {
        $mitigations_list->{sysfs}->{off} = 'Vulnerable: Clear CPU buffers attempted, no microcode; SMT Host state unknown';
    }

}

sub run {
    my ($self) = shift;
    if (is_qemu) {
        update_list_for_qemu();
    }
    my $obj = taa->new($mitigations_list);
    #run base function testing
    $obj->do_test();
}

sub vulnerabilities {
    my $self = shift;
    print "TAA->vulnerabilities\n";
    my $capabilities_taa_no = $self->read_msr() & $self->MSR();
    my $cpuid_rtm = $self->read_cpuid_ebx() & $self->CPUID();
    print "capabilities_taa_no = $capabilities_taa_no\n";
    print "cpuid_rtm = $cpuid_rtm\n";
    if ($capabilities_taa_no == 1 || $cpuid_rtm == 0) {
        record_info("$self->{'name'} Not Affected", "This machine needn't be tested.");
        return 0;
    }
    record_info("$self->{'name'} vulnerable", "Testing will continue.");
    return 1;    #Need change to 1 for Affected
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
    remove_grub_cmdline_settings('tsx=[a-z,]*');
    remove_grub_cmdline_settings("tsx_async_abort=[a-z,]*");
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
