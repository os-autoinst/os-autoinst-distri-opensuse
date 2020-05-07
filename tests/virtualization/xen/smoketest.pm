# VM smoke tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Tests, if the machine is up and running
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

# List of CVEs that are tested by the spectre-meltdown-test script
my %cves = (
    "CVE-2017-5753"  => "Spectre Variant 1",
    "CVE-2017-5715"  => "Spectre Variant 2",
    "CVE-2018-3640"  => "Spectre Variant 3a",
    "CVE-2018-3639"  => "Spectre Variant 4",
    "CVE-2018-3615"  => "Foreshadow (SGX)",
    "CVE-2018-3620"  => "Foreshadow-NG (OS)",
    "CVE-2018-3646"  => "Foreshadow-NG (VMM)",
    "CVE-2018-12126" => "Fallout",
    "CVE-2018-12130" => "ZombieLoad",
    "CVE-2018-12127" => "RIDL",
    "CVE-2019-11091" => "RIDL",
    "CVE-2019-11135" => "ZombieLoad v2",
    "CVE-2018-12207" => "No eXcuses/iTLB Multihit",
);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    my $is_kvm = get_var('KVM') == 1;
    # Print latest Kernel version
    script_run('uname -a');
    script_run('dmesg > /var/tmp/dmesg.txt');
    upload_logs("/var/tmp/dmesg.txt");
    if ($is_kvm) {
        # Check if KVM module is enabled
        script_run("lsmod | grep -e 'kvm_intel\|kvm_amd'");
        record_info('Modules', 'kvm module sucessfully detected');
    }
    # Check meltdown/spectre+variants
    script_run('curl -v -o /var/tmp/spectre-meltdown-checker.sh ' . data_url('virtualization/spectre-meltdown-checker.sh'));
    script_run('chmod 0755 /var/tmp/spectre-meltdown-checker.sh');
    # Run smoketests on guests
    smoketest('localhost');
    foreach my $guest (keys %xen::guests) {
        smoketest($guest);
    }
}


sub smoketest() {
    my $go_to_target = $_[0];
    # Print guest kernel version
    assert_script_run("ssh root\@$go_to_target uname -a");
    # Requirements for spectre-meltdown-checker
    assert_script_run("ssh root\@$go_to_target zypper in -y binutils");
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
            record_soft_failure("$cve ($name) vulnerable on $go_to_target");
        }
    }
}


1;
