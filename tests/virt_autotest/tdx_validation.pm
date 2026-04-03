# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Virtualization TDX guest verification test
# Supports: SLES 16+ host (guests: SLES 16+)
#
# Test description:
# This module tests whether TDX virtual machine has been successfully
# installed on TDX enabled physical host by checking support status
# on the host first and then on the virtual machine itself.
#
# Maintainer: QE-Virtualization <qe-virt@suse.de> tbaev@suse.com

package tdx_validation;

use Mojo::Base 'virt_feature_test_base';
use testapi;
use utils;
use virt_autotest::common;
use virt_autotest::utils;
use version_utils qw(is_sle);
use Utils::Architectures;

sub run_test {
    my $self = shift;

    record_info('TDX Test Started', 'TDX verification test started');

    # Check if host is valid for TDX test
    $self->check_tdx_prerequisites;
    # Check if host TDX is working
    $self->check_tdx_features;
    # Check if guests TDX is working
    $self->check_tdx_guests;

    record_info('TDX Test Completed', 'TDX verification test completed successfully');

    return $self;
}

=head2 check_tdx_prerequisites

  check_tdx_prerequisites($self)

Check whether INTEL TDX is supported by the host.
This function checks the host system architecture, 
OS version, microcode package.

=cut

sub check_tdx_prerequisites {
    my $self = shift;

    record_info('Check TDX support status on host', 'SLES 16+ hosts support TDX.');

    # Collect CPU information for debugging
    my $cpu_info = script_output("grep -m1 'model name' /proc/cpuinfo");
    record_info('CPU Info', "CPU: $cpu_info");
    assert_script_run('lscpu | grep -q "tdx_host_platform"', fail_message => 'CPU does not support TDX');

    # Display system information
    record_info('BIOS Information', script_output("dmidecode -t bios", proceed_on_failure => 1));
    record_info('System Information', script_output("dmidecode -t system", proceed_on_failure => 1));

    # Check architecture
    unless (is_x86_64) {
        record_info('Architecture', 'Non-x86_64 architecture detected, TDX is not supported', result => 'fail');
        die "TDX verification requires x86_64 architecture. Test cannot continue on non-x86_64 platforms.";
    }

    # Check OS version - Only SLES 16+ supported for host
    unless (is_sle('>=16')) {
        record_info('OS Version', 'Host OS version is not SLE 16+, TDX is not supported', result => 'fail');
        die "TDX verification requires SLE 16+ for host. Test cannot continue on unsupported OS version.";
    }

    # Check ucode-intel package is installed
    record_info('Check ucode-intel', 'Microcode Updates for Intel');
    assert_script_run("rpm -q ucode-intel", fail_message => "ucode-intel package is missing");
    assert_script_run("journalctl -k --grep=microcode");    # Check current microcode revision

    record_info('Valid for TDX', "Host is valid for TDX use");
}

=head2 check_tdx_features

  check_tdx_features($self)

Check whether TDX is enabled and active on the host.

Required kernel parameters for TDX (should be set by "EXTRABOOTPARAMS" variable) :
- intel_iommu=on: Enables Intel VT-d to manage hardware memory access and isolate devices.
- iommu=pt: Enables IOMMU pass-through mode
- kvm_intel.tdx=1: Intel KVM module to enable TDX support for guests.
- nohibernate: Disables hibernation, TDX memory is destroyed if the system attempts to hibernate.

=cut

sub check_tdx_features {
    my $self = shift;
    my %required_kernel_params = (
        'intel_iommu=on' => 'Intel IOMMU support',
        'iommu=pt' => 'IOMMU pass-through mode',
        'kvm_intel.tdx=1' => 'Enable Intel TDX module',
        nohibernate => 'Disables hibernation'
    );

    my $cmdline = script_output("cat /proc/cmdline");
    record_info('Kernel cmdline', $cmdline);

    # Check for missing kernel parameters

    foreach my $param (keys %required_kernel_params) {
        if ($cmdline =~ /\b$param\b/) {
            record_info("OK", "Found $param ($required_kernel_params{$param})");
        }
        else {
            record_info("MISSING", "Parameter: $param not found!", result => 'fail');
            die "Parameter: $param not found!";
        }
    }

    my %dmesg_tdx_events = (
        'virt/tdx: BIOS enabled: private KeyID range' => 'TDX enabled and KeyIDs partitioned in BIOS',
        'allocated for PAMT' => 'PAMT memory successfully allocated',
        'virt/tdx: module initialized' => 'TDX kernel module fully initialized'
    );

    # Get dmesg output
    my $dmesg_output = script_output("dmesg");

    # Check dmesg log for TDX init
    foreach my $event (keys %dmesg_tdx_events) {
        if ($dmesg_output =~ /\Q$event\E/) {
            record_info("OK", "Found $event ($dmesg_tdx_events{$event})");
        }
        else {
            record_info("MISSING", "dmesg log: $event not found!", result => 'fail');
            die "dmesg log: $event not found!";
        }
    }

    assert_script_run('cat /sys/module/kvm_intel/parameters/tdx | grep "Y"', fail_message => 'TDX module not found.');
}


=head2 check_tdx_guests

  check_tdx_guests($self)

Check guest is TDX enabled and active on the host.

=cut

sub check_tdx_guests {
    my $self = shift;
    my @guests = keys %virt_autotest::common::guests;

    my %dmesg_guest_events = (
        'tdx: Guest detected' => 'Kernel initialized as TDX guest',
        'Memory Encryption Features active: Intel TDX' => 'TDX memory encryption is active',
        'Detected confidential virtualization tdx' => 'TDX memory encryption is active'
    );

    foreach my $guest (@guests) {
        assert_script_run(
            qq(virsh dumpxml --domain $guest | grep -i "<launchSecurity type='tdx'"),
            fail_message => "Guest $guest is not TDX."
        );
        record_info("GUEST $guest", "launchSecurity = TDX");
        validate_script_output("ssh root\@$guest lscpu", sub { m/tdx_guest/ });
        assert_script_run("ssh root\@$guest test -c /dev/tdx_guest");

        foreach my $event (keys %dmesg_guest_events) {
            assert_script_run(
                "ssh root\@$guest \"dmesg | grep -Fq '$event'\"",
                fail_message => "Guest $guest missing critical dmesg log: $event"
            );
            record_info("GUEST DMESG", "Found: $dmesg_guest_events{$event}");
        }
    }
}

=head2 post_fail_hook

  post_fail_hook($self)

Test run jumps into this subroutine if it fails somehow. It collects supportconfig
and /var/log from guests and calls post_fail_hook in base class.

=cut

sub post_fail_hook {
    my $self = shift;
    record_info('Failure Hook', "Test failed, collecting logs");
    collect_guests_supportconfig_and_logs();
    $self->SUPER::post_fail_hook;
}

1;
