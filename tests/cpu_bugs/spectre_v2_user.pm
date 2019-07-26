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
    name                   => "spectre_v2_user",
    CPUID                  => hex 'C000000',
    IA32_ARCH_CAPABILITIES => 2,                   #bit1 -- EIBRS
    parameter              => 'spectre_v2_user',
    cpuflags               => ['ibpb', 'stibp'],
    sysfs_name             => "spectre_v2",
    sysfs                  => {
        on           => "IBPB: always-on,.* STIBP: forced,.*",
        off          => "IBPB: disabled,.*STIBP: disabled",
        prctl        => "IBPB: conditional.*STIBP: conditional.*",
        prctl_ibpb   => "IBPB: always-on.*STIBP: conditional.*",
        seccomp      => "STIBP: conditional.*",
        seccomp_ibpb => "IBPB: always-on.*STIBP: conditional.*",
        auto         => "IBPB: conditional,.* STIBP: conditional,.*",
    },
    cmdline => [
        "on",
        "off",
        "prctl",
        "prctl,ibpb",
        "seccomp",
        "seccomp,ibpb",
        "auto",
    ],
  );

sub run {
    if (check_var('BACKEND', 'qemu')) {
        $mitigations_list{cpuflags} = ['ibpb'];
        $mitigations_list{sysfs}->{on}           =~ s/STIBP: forced/STIBP: disabled/g;
        $mitigations_list{sysfs}->{prctl}        =~ s/STIBP: conditional/STIBP: disabled/g;
        $mitigations_list{sysfs}->{prctl_ibpb}   =~ s/STIBP: conditional/STIBP: disabled/g;
        $mitigations_list{sysfs}->{seccomp}      =~ s/STIBP: conditional/STIBP: disabled/g;
        $mitigations_list{sysfs}->{seccomp_ibpb} =~ s/STIBP: conditional/STIBP: disabled/g;
        $mitigations_list{sysfs}->{auto}         =~ s/STIBP: conditional/STIBP: disabled/g;
    }
    my $obj = Mitigation->new(\%mitigations_list);
    if (($obj->read_cpuid() & $obj->CPUID()) eq 0) {
        $mitigations_list{sysfs}->{off} = ".*STIBP: disabled";
    }
    #run base function testing
    $obj->do_test();
}


sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('spectre_v2=[a-z,]*');
    remove_grub_cmdline_settings('spectre_v2_user=[a-z,]*');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
