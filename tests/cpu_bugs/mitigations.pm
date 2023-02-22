# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>

use strict;
use warnings;
use base "consoletest";
use bootloader_setup;
use testapi;
use Utils::Backends;
use utils;
use power_action_utils 'power_action';
use Data::Dumper;
use Mitigation;

my @mitigation_module = qw(l1tf mds meltdown spectre_v2 spectre_v4 taa);
#MIssing itlb, spectre_v1
foreach my $item (@mitigation_module) {
    require "$item.pm";
}
my %mitigations_list =
  (
    name => "mitigations",
    parameter => 'mitigations',
    sysfs_name => ["itlb_multihit", "l1tf", "mds", "meltdown", "spec_store_bypass", "spectre_v1", "spectre_v2", "tsx_async_abort"],
    sysfs => {
        auto => {
            itlb_multihit => "KVM: Mitigation: VMX disabled",
            spectre_v1 => "Mitigation: usercopy/swapgs barriers and __user pointer sanitization",
        },
        'auto,nosmt' => {
            itlb_multihit => "KVM: Mitigation: VMX disabled",
            spectre_v1 => "Mitigation: usercopy/swapgs barriers and __user pointer sanitization",
        },
        off => {
            itlb_multihit => "KVM: Mitigation: VMX disabled",
            spectre_v1 => "Vulnerable: __user pointer sanitization and usercopy barriers only; no swapgs barriers",
        },
    },
    cmdline => ["auto,nosmt", "off", "auto"],
  );
# Add icelake of vh018 information
if (get_var('MICRO_ARCHITECTURE') =~ /Icelake/) {
    $mitigations_list{sysfs}{off}{itlb_multihit} = 'Not affected';
    $mitigations_list{sysfs}{"auto,nosmt"}{itlb_multihit} = 'Not affected';
    $mitigations_list{sysfs}{auto}{itlb_multihit} = 'Not affected';
}

sub run {
    my $self = shift;
    select_console 'root-console';

    # When set VUL_SYSFS_DEBUG=1,
    # the test ONLY collects 'sysfs: /sys/devices/system/cpu/vulnerabilities/*'
    # and convert it to hash, then report softfail.
    if (get_var("VUL_SYSFS_DEBUG")) {
        record_info('SYSFS2HASH', "VUL_SYSFS_DEBUG is set");
        dump_sysfs_to_hash();
        record_info("DEBUG", "Only for vulnerabilities sysfs to hash");
        return;
    }

    foreach my $item (@mitigation_module) {
        my $obj;
        my $current_list;

        #UPDATE list for QEMU first
        if (is_qemu) {
            mds::smt_status_qemu();
            taa::update_list_for_qemu();
        }

        #Unable to use dynamic hash name because limitations:
        #Can't use string "taa::mitigations_list" as a HASH ref while "strict refs" in use.
        if ($item eq 'taa' && $taa::mitigations_list) {
            $current_list = $taa::mitigations_list;
            $obj = taa->new($current_list);
            $item = "tsx_async_abort";
        } elsif ($item eq 'meltdown' && $meltdown::mitigations_list) {
            $current_list = $meltdown::mitigations_list;
            $obj = meltdown->new($current_list);
        } elsif ($item eq 'mds' && %mds::mitigations_list) {
            $current_list = \%mds::mitigations_list;
            $obj = Mitigation->new($current_list);
        } elsif ($item eq 'l1tf' && %l1tf::mitigations_list) {
            $current_list = \%l1tf::mitigations_list;
            $obj = Mitigation->new($current_list);
        } elsif ($item eq 'spectre_v2' && %spectre_v2::mitigations_list) {
            $current_list = \%spectre_v2::mitigations_list;
            $obj = Mitigation->new($current_list);
        } elsif ($item eq 'spectre_v4' && %spectre_v4::mitigations_list) {
            $current_list = \%spectre_v4::mitigations_list;
            $obj = Mitigation->new($current_list);
            $item = "spec_store_bypass";
        } else {
            record_info("undefine vulnerabilities items: $item");
        }
        die "Unable to get vulnerabilities instance, exit!" unless $obj;
        my $ret = $obj->vulnerabilities();
        if ($ret eq 1) {
            #off
            $mitigations_list{sysfs}->{off}->{$item} = $current_list->{sysfs}->{off};
            #auto
            if (exists $current_list->{sysfs}->{auto}) {
                $mitigations_list{sysfs}->{auto}->{$item} = $current_list->{sysfs}->{auto};
                if ($item eq 'spectre_v2' && get_var('MICRO_ARCHITECTURE') =~ /Skylake/) {
                    $mitigations_list{sysfs}->{auto}->{$item} = "Mitigation: IBRS, IBPB: conditional, RSB filling.*";
                }
            } elsif (exists $current_list->{sysfs}->{flush}) {
                $mitigations_list{sysfs}->{auto}->{$item} = $current_list->{sysfs}->{flush};
            } elsif (exists $current_list->{sysfs}->{full}) {
                $mitigations_list{sysfs}->{auto}->{$item} = $current_list->{sysfs}->{full};
            }
            #default
            if (exists $current_list->{sysfs}->{default}) {
                $mitigations_list{sysfs}->{default}->{$item} = $current_list->{sysfs}->{default};
            } else {
                $mitigations_list{sysfs}->{default}->{$item} = $mitigations_list{sysfs}->{auto}->{$item};
            }
            #nosmt
            if (exists $current_list->{sysfs}->{'full,nosmt'}) {
                $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = $current_list->{sysfs}->{'full,nosmt'};
            } elsif (exists $current_list->{sysfs}->{'flush_nosmt'}) {
                $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = $current_list->{sysfs}->{'flush_nosmt'};
            } elsif (exists $current_list->{sysfs}->{full_nosmt}) {
                $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = $current_list->{sysfs}->{full_nosmt};
            } else {
                print "$item is vulnerabilities, but unable to get sysfs define on nosmt, try auto";
                $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = $mitigations_list{sysfs}->{auto}->{$item};
                if ($item eq 'spectre_v2') {
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = "Mitigation: Retpolines,.*IBPB: conditional, IBRS_FW*";
                }
                if (get_var('MICRO_ARCHITECTURE') =~ /Skylake/) {
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = "Mitigation: IBRS, IBPB: conditional, RSB filling.*";
                }
            }
            if (is_qemu) {
                #spectre_v2
                if ($item eq 'spectre_v2') {
                    $mitigations_list{sysfs}->{auto}->{'spectre_v2'} =~ s/STIBP: conditional/STIBP: disabled/g;
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{'spectre_v2'} =~ s/STIBP: conditional/STIBP: disabled/g;
                }

                if (get_var('MACHINE', '') =~ /custom/ && $item eq 'spectre_v2') {
                    $mitigations_list{sysfs}->{auto}->{'spectre_v2'} = 'Mitigation: Retpolines,.*IBPB: conditional, IBRS_FW*';
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{'spectre_v2'} = 'Mitigation: Retpolines,.*IBPB: conditional, IBRS_FW*';
                }
                #NO-IBRS
                if (get_var('MACHINE') =~ /^qemu-.*-NO-IBRS$/ && $item eq 'mds') {
                    $mitigations_list{sysfs}->{auto}->{mds} = 'Vulnerable: Clear CPU buffers attempted, no microcode; SMT Host state unknown';
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{mds} = $mitigations_list{sysfs}->{auto}->{mds};
                    $mitigations_list{sysfs}->{off}->{mds} = 'Vulnerable; SMT Host state unknown';
                }
                if (get_var('MACHINE') =~ /^qemu-.*-NO-IBRS$/ && $item eq 'spec_store_bypass') {
                    $mitigations_list{sysfs}->{auto}->{spec_store_bypass} = 'Vulnerable';
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{spec_store_bypass} = $mitigations_list{sysfs}->{auto}->{spec_store_bypass};
                    $mitigations_list{sysfs}->{default}->{spec_store_bypass} = $mitigations_list{sysfs}->{auto}->{spec_store_bypass};
                }
                if (get_var('MACHINE') =~ /^qemu-.*-NO-IBRS$/ && $item eq 'spectre_v2') {
                    $mitigations_list{sysfs}->{auto}->{spectre_v2} = 'Mitigation: Retpolines, STIBP: disabled, RSB filling';
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{spectre_v2} = $mitigations_list{sysfs}->{auto}->{spectre_v2};
                    $mitigations_list{sysfs}->{off}->{spectre_v2} = 'Vulnerable, STIBP: disabled';
                }
                if (get_var('MACHINE') =~ /^qemu-.*-NO-IBRS$/ && $item eq 'tsx_async_abort') {
                    $mitigations_list{sysfs}->{off}->{tsx_async_abort} = 'Vulnerable';
                    $mitigations_list{sysfs}->{auto}->{tsx_async_abort} = 'Vulnerable: Clear CPU buffers attempted, no microcode; SMT Host state unknown';
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{tsx_async_abort} = $mitigations_list{sysfs}->{auto}->{tsx_async_abort};
                    $mitigations_list{sysfs}->{default}->{tsx_async_abort} = $mitigations_list{sysfs}->{auto}->{tsx_async_abort};
                }
                if (get_var('MACHINE', '') =~ /passthrough/ && $item eq 'l1tf') {
                    $mitigations_list{sysfs}->{auto}->{l1tf} = 'Mitigation: PTE Inversion; VMX: flush not necessary, SMT disabled';
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{l1tf} = $mitigations_list{sysfs}->{auto}->{l1tf};
                    $mitigations_list{sysfs}->{off}->{l1tf} = $mitigations_list{sysfs}->{auto}->{l1tf};
                    $mitigations_list{sysfs}->{default}->{l1tf} = $mitigations_list{sysfs}->{auto}->{l1tf};
                } elsif ($item eq 'l1tf') {
                    $mitigations_list{sysfs}->{auto}->{l1tf} = "Mitigation: PTE Inversion";
                    $mitigations_list{sysfs}->{off}->{l1tf} = $mitigations_list{sysfs}->{auto}->{l1tf};
                    $mitigations_list{sysfs}->{'auto,nosmt'}->{l1tf} = $mitigations_list{sysfs}->{auto}->{l1tf};
                    $mitigations_list{sysfs}->{default}->{l1tf} = $mitigations_list{sysfs}->{auto}->{l1tf};
                }
            }
        } elsif ($ret eq 0) {
            record_info("Not affected", "$item");
            $mitigations_list{sysfs}->{auto}->{$item} = "Not affected";
            $mitigations_list{sysfs}->{off}->{$item} = "Not affected";
            $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = "Not affected";
            if ($item eq 'spectre_v2') {
                record_info("EIBRS", "This machine support EIBRS on spectre_v2");
                $mitigations_list{sysfs}->{auto}->{$item} = "Mitigation: Enhanced IBRS, IBPB: conditional, RSB filling";
                $mitigations_list{sysfs}->{'auto,nosmt'}->{$item} = "Mitigation: Enhanced IBRS, IBPB: conditional, RSB filling";
                $mitigations_list{sysfs}->{off}->{$item} = $current_list->{sysfs}->{off};
            }
        } else {
            die("$item vulnerabilities is unkown");
        }
    }

    #Handle itlb_multihit
    if (is_qemu) {
        if (get_var('MACHINE', '') =~ /passthrough/) {
            record_info("itlb_multihit Not affected", "itlb_multihit is not affected on qemu passthrough");
            $mitigations_list{sysfs}->{auto}->{'itlb_multihit'} = "Not affected";
            $mitigations_list{sysfs}->{off}->{'itlb_multihit'} = "Not affected";
            $mitigations_list{sysfs}->{'auto,nosmt'}->{'itlb_multihit'} = "Not affected";
        } else {
            $mitigations_list{sysfs}->{off}->{'itlb_multihit'} = "KVM: Mitigation: VMX unsupported";
            $mitigations_list{sysfs}->{auto}->{'itlb_multihit'} = "KVM: Mitigation: VMX unsupported";
            $mitigations_list{sysfs}->{'auto,nosmt'}->{'itlb_multihit'} = "KVM: Mitigation: VMX unsupported";
        }
    }

    print Dumper \%mitigations_list;
    my $test_obj = Mitigation->new(\%mitigations_list);
    $test_obj->do_test();
}


sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; head /sys/devices/system/cpu/vulnerabilities/* > /tmp/upload_mitigations/vulnerabilities; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('mitigations=[a-z,]*');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

sub dump_sysfs_to_hash {
    my ($self) = @_;
    my %ret_data;

    assert_script_run('cat /proc/cmdline');
    my $ret = script_run('grep "' . "mitigations" . '=[a-z]*" /proc/cmdline');
    if ($ret eq 0) {
        remove_grub_cmdline_settings("mitigations=[a-z,]*");
    }
    grub_mkconfig();
    Mitigation::reboot_and_wait($self, 150);
    assert_script_run('cat /proc/cmdline');
    script_run("head /sys/devices/system/cpu/vulnerabilities/* > /tmp/vulnerabilities.manual.txt");
    upload_logs "/tmp/vulnerabilities.manual.txt";

    my @kernel_parameter = ("off", "auto", "auto,nosmt");
    foreach my $cmd (@kernel_parameter) {
        record_info("$cmd");
        add_grub_cmdline_settings("mitigations=" . $cmd);
        grub_mkconfig();
        clear_console;
        Mitigation::reboot_and_wait($self, 150);
        assert_script_run('cat /proc/cmdline');
        my $script_output = script_output("grep -H . /sys/devices/system/cpu/vulnerabilities/*");
        my %tmp_hash;
        foreach my $line (split(/\n/, $script_output)) {
            my @tmp = split(/([^\/]+?):(.+)/, $line);
            $tmp_hash{$tmp[1]} = $tmp[2];
        }
        $ret_data{$cmd} = \%tmp_hash;

        $cmd =~ s/,/_/ig;
        my $logfile = "vulnerabilities.$cmd.txt";
        script_run("head /sys/devices/system/cpu/vulnerabilities/* > /tmp/$logfile");
        upload_logs "/tmp/$logfile";
        remove_grub_cmdline_settings("mitigations=[a-z,]*");
    }
    print Dumper \%ret_data;
}


1;
