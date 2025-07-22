# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>
package spectre_v4;

use base "consoletest";
use bootloader_setup;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;

use Mitigation;

our %mitigations_list =
  (
    name => "spectre_v4",
    CPUID => hex '80000000',
    IA32_ARCH_CAPABILITIES => 16,    #bit4 --SSB_NO
    parameter => 'spec_store_bypass_disable',
    cpuflags => ['ssbd'],
    sysfs_name => "spec_store_bypass",
    sysfs => {
        on => "Mitigation: Speculative Store Bypass disabled",
        off => "Vulnerable",
        auto => "Mitigation: Speculative Store Bypass disabled via prctl",
        prctl => "Mitigation: Speculative Store Bypass disabled via prctl",
        seccomp => "Mitigation: Speculative Store Bypass disabled via prctl and seccomp",
        default => "Mitigation: Speculative Store Bypass disabled via prctl",
    },
    cmdline => [
        "on",
        "off",
        "auto",
        "prctl",
        "seccomp",
    ],
  );

sub run {
    my $obj = Mitigation->new(\%mitigations_list);
    #run base function testing
    $obj->do_test();
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('spec_store_bypass_disable=[a-z,]*');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
