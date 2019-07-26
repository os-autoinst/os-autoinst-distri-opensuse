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
    if (check_var('BACKEND', 'qemu')) {
        record_info('softfail', "QEMU needn't run this testcase");
        return;
    }
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
    remove_grub_cmdline_settings('l1tf=[a-z,]*');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
    $self->SUPER::post_fail_hook;
}

1;
