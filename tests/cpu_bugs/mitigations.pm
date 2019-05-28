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
    name       => "mitigations",
    parameter  => 'mitigations',
    sysfs_name => ["mds", "l1tf", "meltdown", "spec_store_bypass", "spectre_v2"],
    sysfs      => {
        off => {
            mds               => "Mitigation: Clear CPU buffers; SMT vulnerable",
            l1tf              => "Mitigation: PTE Inversion; VMX: vulnerable",
            spectre_v2        => "Vulnerable,.*IBPB: disabled,.*STIBP: disabled",
            meltdown          => "Vulnerable",
            spec_store_bypass => "Vulnerable",
        },
        auto_nosmt => {
            mds  => "Mitigation: Clear CPU buffers; SMT disabled",
            l1tf => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled",
        },
    },
    cmdline => [
        "auto,nosmt",
        "off",
    ],
  );

sub check_sysfs {
    my ($self, $value) = @_;
    record_info('mitigations', "this check_sysfs is overwrited!");
    foreach my $sysfs (@{$self->Sysfs()}) {
        assert_script_run('cat ' . $Mitigation::syspath . $sysfs);
        if (@_ == 2) {
            assert_script_run(
                'cat ' . $Mitigation::syspath . $sysfs . '| grep ' . '"' . $self->sysfs($value)->{$sysfs} . '"');
        }
    }
}

sub run {
    if (check_var('BACKEND', 'qemu')) {
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
    remove_grub_cmdline_settings('mitigations=[a-z,]*');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
