# VM smoke tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh binutils util-linux
# Summary: Tests, if the machine is up and running
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virt_autotest::utils;

# List of CVEs that are tested by the spectre-meltdown-test script
my %cves = (
    "CVE-2017-5753" => "Spectre Variant 1",
    "CVE-2017-5715" => "Spectre Variant 2",
    "CVE-2018-3640" => "Spectre Variant 3a",
    "CVE-2018-3639" => "Spectre Variant 4",
    "CVE-2018-3615" => "Foreshadow (SGX)",
    "CVE-2018-3620" => "Foreshadow-NG (OS)",
    "CVE-2018-3646" => "Foreshadow-NG (VMM)",
    "CVE-2018-12126" => "Fallout",
    "CVE-2018-12130" => "ZombieLoad",
    "CVE-2018-12127" => "RIDL",
    "CVE-2019-11091" => "RIDL",
    "CVE-2019-11135" => "ZombieLoad v2",
    "CVE-2018-12207" => "No eXcuses/iTLB Multihit",
);

sub run_test {
    my $self = shift;
    $self->select_serial_terminal;

    # Print latest Kernel version
    script_run('uname -a');
    script_run('dmesg > /var/tmp/dmesg.txt');
    upload_logs("/var/tmp/dmesg.txt");
    if (is_kvm_host) {
        # Check if KVM module is enabled
        script_run("lsmod | grep -e 'kvm_intel\|kvm_amd'");
        record_info('Modules', 'kvm module sucessfully detected');
    }
    # Check meltdown/spectre+variants
    script_run('curl -v -o /var/tmp/spectre-meltdown-checker.sh ' . data_url('virtualization/spectre-meltdown-checker.sh'));
    script_run('chmod 0755 /var/tmp/spectre-meltdown-checker.sh');
    # Run smoketests on guests
    smoketest('localhost');
    foreach my $guest (keys %virt_autotest::common::guests) {
        # This should fix some common issues on the guests. If the procedure fails we still want to go on
        eval {
            ensure_online($guest);
        } or do {
            my $err = $@;
            record_info("$guest failure: $err");
        };
        smoketest($guest);
    }
}

sub ignore_cve_fail {
    my $cve = $_[0];
    my $guest = $_[1];

    # Exceptions we are aware of
    return 1 if $cve =~ /^CVE-2017-5753$/i and $guest =~ /sles11sp4/i;
    return 1 if $cve =~ /^CVE-2017-5715$/i and $guest =~ /sles11sp4/i;
    return 1 if $cve =~ /^CVE-2018-3639$/i and $guest =~ /sles11sp4/i;
    return 1 if $cve =~ /^CVE-2018-3646$/i;
    return 1 if $cve =~ /^CVE-2017-5754$/i and is_xen_host;

    return 0;
}

sub smoketest() {
    my $go_to_target = $_[0];
    # Print guest kernel version
    assert_script_run("ssh root\@$go_to_target uname -a");
    # Requirements for spectre-meltdown-checker
    assert_script_run("ssh root\@$go_to_target zypper in -y binutils || true", 180);
    if ($go_to_target ne "" && $go_to_target ne "localhost") {
        assert_script_run("scp /var/tmp/spectre-meltdown-checker.sh root\@$go_to_target:/var/tmp/spectre-meltdown-checker.sh");
    }
    assert_script_run("ssh root\@$go_to_target '/var/tmp/spectre-meltdown-checker.sh --no-color' | tee /var/tmp/spectre-meltdown-checker-$go_to_target.txt");
    upload_logs("/var/tmp/spectre-meltdown-checker-$go_to_target.txt", timeout => 90);
    assert_script_run("ssh root\@$go_to_target '/var/tmp/spectre-meltdown-checker.sh --batch text' | tee /var/tmp/spectre-meltdown-checker-$go_to_target.out");

    # Test for CVEs
    for my $cve (keys %cves) {
        my $name = $cves{$cve};
        if (script_run("grep '$cve: OK' /var/tmp/spectre-meltdown-checker-$go_to_target.out")) {
            # Check if failure comes from outdated CPU microcode (we still test on old hardware!)
            if (script_run("grep '$cve:' /var/tmp/spectre-meltdown-checker-$go_to_target.out | grep \"Your kernel supports mitigation, but your CPU microcode also needs to be updated to mitigate the vulnerability\|an up-to-date CPU microcode is needed to mitigate this vulnerability\|Your CPU doesn't support SSBD\"")) {
                record_info("$name", "Cannot test $cve ($name) on $go_to_target (outdated CPU microcode or kernel)");
                # Or special known failure
            } elsif ($cve =~ /^CVE-2018-3646$/i && script_run("grep '$cve:' /var/tmp/spectre-meltdown-checker-$go_to_target.out | grep 'disable EPT or enable L1D flushing to mitigate the vulnerability'")) {
                record_info("$name", "$cve ($name) on $go_to_target vulnerable (expensive mitigations disabled by default)");
            } else {
                # Some failures are OK but we still want to record them
                record_soft_failure("$cve ($name) vulnerable on $go_to_target") unless ignore_cve_fail($cve, $go_to_target);
                record_info("$name", "$cve ($name) vulnerable on $go_to_target") if ignore_cve_fail($cve, $go_to_target);
            }
        }
    }
}


1;
