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
use mds;
use taa;

print "mds_taa.pm -> load\n";

my %mds_taa_list =
  (
    name       => "mds_taa",
    parameter  => ["mds", "tsx_async_abort"],
    sysfs_name => ["mds", "tsx_async_abort"],
    sysfs      => {
        off => {
            mds             => "Vulnerable; SMT vulnerable",
            tsx_async_abort => "Vulnerable",
        },
        full => {
            mds             => "Mitigation: Clear CPU buffers; SMT vulnerable",
            tsx_async_abort => "Mitigation: Clear CPU buffers; SMT vulnerable",
        },
        default => {
            mds             => "Mitigation: Clear CPU buffers; SMT vulnerable",
            tsx_async_abort => "Mitigation: Clear CPU buffers; SMT vulnerable",
        },
        "full,nosmt" => {
            mds             => "Mitigation: Clear CPU buffers; SMT disabled",
            tsx_async_abort => "Mitigation: Clear CPU buffers; SMT disabled",
        },
    },
    cmdline => [
        "full",
        "off",
        "full,nosmt",
    ],
  );

sub update_list_for_qemu {
    my $self = shift;

    $mds_taa_list{sysfs}->{full}->{mds}         =~ s/SMT vulnerable/SMT Host state unknown/ig;
    $mds_taa_list{sysfs}->{"full,nosmt"}->{mds} =~ s/SMT disabled/SMT Host state unknown/ig;
    $mds_taa_list{sysfs}->{default}->{mds}      =~ s/SMT vulnerable/SMT Host state unknown/ig;
    $mds_taa_list{sysfs}->{off}->{mds} = "Vulnerable; SMT Host state unknown";

    $mds_taa_list{sysfs}->{full}->{tsx_async_abort}         =~ s/SMT vulnerable/SMT Host state unknown/ig;
    $mds_taa_list{sysfs}->{"full,nosmt"}->{tsx_async_abort} =~ s/SMT disabled/SMT Host state unknown/ig;
    $mds_taa_list{sysfs}->{default}->{tsx_async_abort}      =~ s/SMT vulnerable/SMT Host state unknown/ig;

    if (get_var('MACHINE') =~ /^qemu-.*-NO-IBRS$/) {
        $mds_taa_list{sysfs}->{default}->{mds}                  = 'Vulnerable: Clear CPU buffers attempted, no microcode; SMT Host state unknown';
        $mds_taa_list{sysfs}->{default}->{tsx_async_abort}      = 'Vulnerable: Clear CPU buffers attempted, no microcode; SMT Host state unknown';
        $mds_taa_list{sysfs}->{off}->{mds}                      = $mds_taa_list{sysfs}->{default}->{mds};
        $mds_taa_list{sysfs}->{off}->{tsx_async_abort}          = $mds_taa_list{sysfs}->{default}->{mds};
        $mds_taa_list{sysfs}->{full}->{mds}                     = $mds_taa_list{sysfs}->{default}->{mds};
        $mds_taa_list{sysfs}->{full}->{tsx_async_abort}         = $mds_taa_list{sysfs}->{default}->{tsx_async_abort};
        $mds_taa_list{sysfs}->{'full,nosmt'}->{mds}             = $mds_taa_list{sysfs}->{default}->{mds};
        $mds_taa_list{sysfs}->{'full,nosmt'}->{tsx_async_abort} = $mds_taa_list{sysfs}->{default}->{tsx_async_abort};
    }
}

sub run {
    my $self = shift;

    my $taa_obj     = taa->new($taa::mitigations_list);
    my $mds_obj     = Mitigation->new(\%mds::mitigations_list);
    my $taa_vul_ret = $taa_obj->vulnerabilities();
    my $mds_vul_ret = $mds_obj->vulnerabilities();
    print "taa_vul_ret = $taa_vul_ret\n";
    print "mds_vul_ret = $mds_vul_ret\n";

    if ($taa_vul_ret and $mds_vul_ret) {
        record_info("Both TAA and MDS", "Testing will continue.");
        if (check_var('BACKEND', 'qemu')) {
            update_list_for_qemu();
        }
        my $mds_taa_obj = Mitigation->new(\%mds_taa_list);
        $mds_taa_obj->do_test();
    } elsif ($taa_vul_ret and !$mds_vul_ret) {
        record_info("TAA vulnerable only", "launch TAA testing");
        autotest::loadtest("tests/cpu_bugs/taa.pm");
    } elsif (!$taa_vul_ret and $mds_vul_ret) {
        record_info("MDS vulnerable only", "launch MDS testing");
        autotest::loadtest("tests/cpu_bugs/mds.pm");
    }
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('mds=[a-z,]*');
    remove_grub_cmdline_settings('taa=[a-z,]*');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
