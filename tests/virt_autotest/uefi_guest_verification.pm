# VIRTUAL MACHINE UEFI FEATURES VERIFICATION MODULE
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module tests virtual machine with UEFI/Secureboot by
# using efibootmgr -v and mokutil --sb-state.And also performs power
# management operations,including suspend to memory,disk and hybrid
# on each virtual machine.
#
# Maintainer: Wayne Chen <wchen@suse.com>
package uefi_guest_verification;

use base 'virt_feature_test_base';
use POSIX 'strftime';
use File::Basename;
use testapi;
use IPC::Run;
use utils;
use virt_utils;
use virt_autotest::common;
use virt_autotest::utils;
use version_utils qw(is_sle is_alp);
use Utils::Architectures;

sub run_test {
    my $self = shift;

    $self->check_guest_bootloader($_) foreach (keys %virt_autotest::common::guests);
    $self->check_guest_bootcurrent($_) foreach (keys %virt_autotest::common::guests);

    # No machine type on aarch64 supports power management, or secure boot
    return $self if (is_aarch64);

    if (is_sle('>=15-SP7')) {
        $self->check_guest_secure_boot($_) foreach (keys %virt_autotest::common::guests);
        #$self->check_guest_uefi_boot($_) foreach (keys %virt_autotest::common::guests);
    }
    record_soft_failure("UEFI implementation for xen fullvirt uefi virtual machine is incomplete. bsc#1184936 Xen fullvirt lacks of complete support for UEFI") if (is_xen_host);

    # TODO: enable pm check for alp once default uefi firmware supports it well
    if (is_sle('>=15')) {
        $self->check_guest_pmsuspend_enabled;
    }
    elsif (is_alp) {
        record_info("Skip power management check on ALP", "The uefi firmware does not support pm well.");
    }
    else {
        record_info("SLES that is eariler than 15 does not support power management functionality with uefi", "Skip check_guest_pmsuspend_enabled");
    }
    return $self;
}

sub check_guest_bootloader {
    my ($self, $guest_name) = @_;

    record_info("Basic bootloader checking on $guest_name", "efibootmgr -v and mokutil --sb-state should return successfully");
    my $ssh_command_prefix = "ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    script_retry("$ssh_command_prefix root\@$guest_name efibootmgr -v");
    script_retry("$ssh_command_prefix root\@$guest_name mokutil --sb-state", die => 0);
    return $self;
}

sub check_guest_bootcurrent {
    my ($self, $guest_name) = @_;

    record_info("Booted os checking on $guest_name", "Booted os should be sles if $guest_name is installed as such judging by /etc/os-release");
    my $ssh_command_prefix = "ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    my $current_boot_entry = script_output("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -i BootCurrent | grep -oE [[:digit:]]+");
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -i \"BootOrder: $current_boot_entry\"");
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -i Boot$current_boot_entry.*sles") if (script_output("$ssh_command_prefix root\@$guest_name cat /etc/os-release | grep -io \"SUSE Linux Enterprise Server.*\"", proceed_on_failure => 1) ne '');
    return $self;
}

sub check_guest_uefi_boot {
    my ($self, $guest_name) = @_;

    record_info("UEFI boot entries checking on $guest_name", "The latest UEFI should support PXEv6 and HTTPv6 boots if $guest_name is also configured correctly");
    my $ssh_command_prefix = "timeout 30 ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -iE \"uefi.*pxev6\"");
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -iE \"uefi.*HTTPv6\"");
    return $self;
}

sub check_guest_secure_boot {
    my ($self, $guest_name) = @_;

    record_info("UEFI SecureBoot checking on $guest_name", "SecureBoot should be enabled if $guest_name is also configured correctly");
    my $ssh_command_prefix = "timeout 30 ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    assert_script_run("$ssh_command_prefix root\@$guest_name mokutil --sb-state | grep -iE \"secureboot.*enabled\"");
    return $self;
}

# PED-87 Do NOT auto-generate EFI secret-key for hibernation verification leads
# to bsc#1230977 Fail to dompmsuspend 15SP7 FV UEFI guest system. In order to
# continue to perform power management, regenerating efi secret key and reboot
# for uefi guest is needed. Only hybrid and disk suspend modes need do this.
sub regen_efi_secret_key {
    my ($self, $guest) = @_;

    execute_over_ssh(address => $guest, command => 'echo 1 > /sys/firmware/efi/secret-key/regen');
    reboot_virtual_machine(address => $guest);
}

sub check_guest_pmsuspend_enabled {
    my $self = shift;
    foreach (keys %virt_autotest::common::guests) {
        record_soft_failure("Bug bsc#1257492: qemu-guest-agent is not installed by default. We have workaround to install it in jsonnet.") if ($_ =~ /sles-16-1/i);
        $self->do_guest_pmsuspend($_, 'mem');
    }
    if (is_kvm_host) {
        foreach (keys %virt_autotest::common::guests) {
            if (is_sle('>=15') and ($_ =~ /12-sp5/img)) {
                record_info("PMSUSPEND to hyrbrid is not supported here", "Guest $_ on kvm sles 15+ host");
                next;
            }
            $self->regen_efi_secret_key($_) if (is_sle('>=15') or ($_ =~ /sles-15|sles15/img));
            $self->do_guest_pmsuspend($_, 'hybrid');
        }
        foreach (keys %virt_autotest::common::guests) {
            if (is_sle('>=15') and ($_ =~ /12-sp5/img)) {
                record_info("PMSUSPEND to disk is not supported here", "Guest $_ on kvm sles 15+ host");
                next;
            }
            $self->regen_efi_secret_key($_) if (is_sle('>=15') or ($_ =~ /sles-15|sles15/img));
            $self->do_guest_pmsuspend($_, 'disk');
        }
    }
    else {
        record_soft_failure("UEFI implementation for xen fullvirt uefi virtual machine is incomplete. bsc#1184936 Xen fullvirt lacks of complete support for UEFI");
    }
    return $self;
}

sub do_guest_pmsuspend {
    my ($self, $suspend_domain, $suspend_target, $suspend_duration) = @_;
    carp("Guest domain name must be given before performing dompmsuspend.") if (!(defined $suspend_domain) or ($suspend_domain eq ''));
    $suspend_target //= 'mem';
    $suspend_duration //= 0;

    record_info("PM suspend to $suspend_target on $suspend_domain test", "Xen only supports suspend to memory, kvm also supports suspend to disk and hybrid modes");
    my $guest_state_after_suspend = 'pmsuspended';
    $guest_state_after_suspend = 'shut off' if ($suspend_target eq 'disk');
    assert_script_run("virsh dompmsuspend --domain $suspend_domain --target $suspend_target");
    script_retry("virsh list --all  | grep -i $suspend_domain | grep -i \"$guest_state_after_suspend\"", delay => 10, retry => 5);
    if ($suspend_target eq 'disk') {
        assert_script_run("virsh start --domain $suspend_domain");
    }
    else {
        assert_script_run("virsh dompmwakeup --domain $suspend_domain");
    }
    assert_script_run("virsh list --all  | grep -i $suspend_domain | grep -i running");
    script_retry("ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_ efibootmgr -v", delay => 60, retry => 3);
    return $self;
}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook;
    return $self;
}

1;
