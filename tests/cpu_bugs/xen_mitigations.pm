# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>
#
# This testsuite for the spectre control mitigations on XEN hypervisor.
#
# From xen's oneline doc:
# http://xenbits.xen.org/docs/4.12-testing/misc/xen-command-line.html#xpti-x86
# http://xenbits.xen.org/docs/4.12-testing/misc/xen-command-line.html#spec-ctrl-x86
# http://xenbits.xen.org/docs/4.12-testing/misc/xen-command-line.html#pv-l1tf-x86
#
# We testing each of parameter. To check the influence of each of them.
#
# There is a data structure to store the data that for compare with the data in runtime system.
# When we found something of unexpection string, we call them go die.
# When we didn't find something of expection string, we call them go die too.
#
# mitigations_list = {
#	'<parameter name>' => {
#		<the value of parameter> => {
#			<secnario1> => {
#				#determine string.
#				determine => {'<cmd>' => ['']},
#				#expection string. If it doesn't appear go die
#				expected => {'<cmd>' => ['ecpection string1','expection string2']},
#				#unexpection string. If it appears go die.
#				unexpected => {'<cmd>' => ['unexpection string1']}
#			}
#			<secnario2> => {
#				.....
#			}
#		}
#	}
# }
# Put into xpti, spec-ctrl, into this structure. and The testing code will read all them and
# one by one execution checking.
#

package xen_mitigations;
use strict;
use warnings;
use base "consoletest";
use bootloader_setup;
use Mitigation;
use ipmi_backend_utils;
use testapi;
use utils;

my $xpti_true = {true => {
        default => {
            expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU enabled']},
            unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU disabled', 'XPTI (64-bit PV only): Dom0 disabled, DomU enabled', 'XPTI (64-bit PV only): Dom0 disabled, DomU disabled']}
        }
    }
};
my $xpti_false = {false => {
        default => {
            expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 disabled, DomU disabled']},
            unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU disabled', 'XPTI (64-bit PV only): Dom0 enabled, DomU enabled', 'XPTI (64-bit PV only): Dom0 disabled, DomU enabled']}
        }
    }
};
my $xpti_dom0_true = {"dom0=true" => {
        default => {
            expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU .*$']},
            unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 disabled, DomU .*$']}
        }
    }
};
my $xpti_dom0_false = {"dom0=false" => {
        default => {
            expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 disabled, DomU .*$']},
            unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU .*$']}
        }
    }
};
my $xpti_domu_true = {"domu=true" => {
        default => {
            expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU enabled']},
            unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU disabled']}
        }
    }
};
my $xpti_domu_false = {"domu=false" => {
        default => {
            expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU disabled']},
            unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU enabled']}
        }
    }
};

# Test Case for spec_ctrl
my $spec_ctrl_no = {no => {
        default => {
            #expection string. If it doesn't appear go die
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk JMP, SPEC_CTRL: IBRS- STIBP- SSBD-.*, Other:$',
'Support for HVM VMs: MD_CLEAR', 'Support for PV VMs: MD_CLEAR', '^(XEN)   XPTI (64-bit PV only): Dom0 disabled, DomU disabled (with PCID)$', '^(XEN)   PV L1TF shadowing: Dom0 disabled, DomU disabled$']},
            #unexpection string. If it appears go die.
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_no_xen = {"no-xen" => {
        default => {
            expected => {'xl dmesg' => ['Xen settings: BTI-Thunk JMP, SPEC_CTRL: IBRS- STIBP- SSBD-.*, Other:$']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_pv_on = {"pv=on" => {
        default => {
            expected => {'xl dmesg' => ['Support for PV VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_pv_0 = {"pv=0" => {
        default => {
            expected => {'xl dmesg' => ['Support for PV VMs: EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_hvm_on = {"hvm=on" => {
        default => {
            expected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_hvm_0 = {"hvm=0" => {
        default => {
            expected => {'xl dmesg' => ['Support for HVM VMs: EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_msr_sc_on = {"msr-sc=on" => {
        default => {
            expected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR', 'Support for PV VMs: MSR_SPEC_CTRL EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_msr_sc_off = {"msr-sc=off" => {
        default => {
            expected => {'xl dmesg' => ['Support for HVM VMs: RSB EAGER_FPU MD_CLEAR', 'Support for PV VMs: EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_rsb_on = {"rsb=on" => {
        default => {
            expected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR', 'Support for PV VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_rsb_off = {"rsb=off" => {
        default => {
            expected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL EAGER_FPU MD_CLEAR', 'Support for PV VMs: MSR_SPEC_CTRL EAGER_FPU MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_md_clear_off = {"md-clear=off" => {
        default => {
            #even md-clear=off
            expected => {'xl dmesg' => ['Support for HVM VMs: .*MD_CLEAR', 'Support for PV VMs: .*MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_md_clear_on = {"md-clear=on" => {
        default => {
            expected => {'xl dmesg' => ['Support for HVM VMs: .*MD_CLEAR', 'Support for PV VMs: .*MD_CLEAR']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_bti_thunk_retp_for_intel = {"bti-thunk=retpoline" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk RETPOLINE, SPEC_CTRL: IBRS+ STIBP- SSBD-.*, Other:']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_bti_thunk_retp_for_amd = {"bti-thunk=lfence" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk LFENCE, SPEC_CTRL: IBRS+ SSBD-.*, Other:']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_bti_thunk_jmp = {"bti-thunk=jmp" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk JMP, SPEC_CTRL: IBRS+ STIBP- SSBD-.*, Other:']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_ibrs_off = {"ibrs=off" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS- STIBP- SSBD-.*, Other:']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_ibrs_on = {"ibrs=on" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS+ STIBP- SSBD-.*, Other:']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_ibpb_off = {"ibpb=off" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. STIBP- SSBD-.*, Other:']},
            unexpected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other:.*IBPB']}
        }
    }
};
my $spec_ctrl_ibpb_on = {"ibpb=on" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. STIBP- SSBD-.*, Other: IBPB']},
            unexpected => {'xl dmesg' => ['']}
        }
    }
};
my $spec_ctrl_ssbd_off = {"ssbd=off" => {
        default => {
            expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. STIBP- SSBD-.*, Other:']},
            unexpected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD\+.*(TSX|).*, Other:']}
        }
    }
};
my $spec_ctrl_ssbd_on = {"ssbd=on" => {
        default => {
            expected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. STIBP- SSBD+.*, Other:']},
            unexpected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other:']}
        }
    }
};
my $spec_ctrl_eager_fpu_off = {"eager-fpu=off" => {
        default => {
            expected => {'xl dmesg' => ['Support for .* VMs: MSR_SPEC_CTRL RSB MD_CLEAR']},
            unexpected => {'xl dmesg' => ['Support for .* VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']}
        }
    }
};
my $spec_ctrl_eager_fpu_on = {"eager-fpu=on" => {
        default => {
            expected => {'xl dmesg' => ['Support for .* VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
            unexpected => {},
        }
    }
};
my $spec_ctrl_l1d_flsh_off = {"l1d-flush=off" => {
        default => {
            expected => {},
            unexpected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: .*L1D_FLUSH']},
        }
    }
};
my $spec_ctrl_l1d_flsh_on = {"l1d-flush=on" => {
        default => {
            expected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. STIBP- SSBD-.*, Other: .*L1D_FLUSH']},
            unexpected => {},
        }
    }
};
my $spec_ctrl_branch_harden_on = {"branch-harden=on" => {
        default => {
            expected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. STIBP- SSBD-.*, Other: .*BRANCH_HARDEN']},
            unexpected => {},
        }
    }
};
my $spec_ctrl_branch_harden_off = {"branch-harden=off" => {
        default => {
            expected => {},
            unexpected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: .*BRANCH_HARDEN']},
        }
    }
};
# Test cases for TAA
my $tsx_off_for_haswell = {off => {
        default => {
            expected => {'xl info' => ['tsx=off']},
            unexpected => {},
        }
    }
};

my $tsx_on_for_haswell = {on => {
        default => {
            expected => {'xl info' => ['tsx=on']},
            unexpected => {},
        }
    }
};

my $tsx_off_for_non_haswell = {off => {
        default => {
            expected => {'xl info' => ['tsx=off']},
            unexpected => {},
        }
    }
};

my $tsx_on_for_non_haswell = {on => {
        default => {
            expected => {'xl info' => ['tsx=on']},
            unexpected => {},
        }
    }
};

# Test case for pv-l1tf
my $pv_l1tf_true = {
    true => {
        default => {
            expected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 enabled, DomU enabled']},
            unexpected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 disabled, DomU enabled', 'PV L1TF shadowing: Dom0 enabled, DomU disabled', 'PV L1TF shadowing: Dom0 disabled, DomU disabled']}
        }
    }
};
my $pv_l1tf_false = {false => {
        default => {
            expected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 disabled, DomU disabled']},
            unexpected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 disabled, DomU enabled', 'PV L1TF shadowing: Dom0 enabled, DomU disabled', 'PV L1TF shadowing: Dom0 enabled, DomU enabled']}
        }
    }
};
my $pv_l1tf_dom0_true = {"dom0=true" => {
        default => {
            expected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 enabled']},
            unexpected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 disabled']}
        }
    }
};
my $pv_l1tf_dom0_false = {"dom0=false" => {
        default => {
            expected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 disabled']},
            unexpected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 enabled']}
        }
    }
};
my $pv_l1tf_domu_true = {"domu=true" => {
        default => {
            expected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 disabled, DomU enabled']},
            unexpected => {'xl dmesg' => ['PV L1TF shadowing: Dom0.*, DomU disabled']}
        }
    }
};
my $pv_l1tf_domu_false = {"domu=false" => {
        default => {
            expected => {'xl dmesg' => ['PV L1TF shadowing: Dom0 disabled, DomU disabled']},
            unexpected => {'xl dmesg' => ['PV L1TF shadowing: Dom0.*, DomU enabled']}
        }
    }
};

# Generate full test cases hash
my $xpti_hash = {%$xpti_true, %$xpti_false, %$xpti_dom0_true, %$xpti_dom0_false, %$xpti_domu_true, %$xpti_domu_false};

my $spec_ctrl_hash = {%$spec_ctrl_no, %$spec_ctrl_no_xen, %$spec_ctrl_pv_on, %$spec_ctrl_pv_0,
    %$spec_ctrl_hvm_on, %$spec_ctrl_hvm_0, %$spec_ctrl_msr_sc_on, %$spec_ctrl_msr_sc_off,
    %$spec_ctrl_rsb_on, %$spec_ctrl_rsb_off, %$spec_ctrl_md_clear_off, %$spec_ctrl_md_clear_on,
    %$spec_ctrl_ibrs_off, %$spec_ctrl_ibrs_on, %$spec_ctrl_ibpb_off, %$spec_ctrl_ibpb_on,
    %$spec_ctrl_ssbd_off, %$spec_ctrl_ssbd_on, %$spec_ctrl_eager_fpu_off, %$spec_ctrl_eager_fpu_on,
    %$spec_ctrl_l1d_flsh_off, %$spec_ctrl_l1d_flsh_on, %$spec_ctrl_branch_harden_on,
    %$spec_ctrl_branch_harden_off, %$spec_ctrl_bti_thunk_jmp};

# TODO
if (get_var('ARCH', '') =~ /amd/i) {
    ${$spec_ctrl_hash}{'bti-thunk=lfence'} = ${$spec_ctrl_bti_thunk_retp_for_amd}{'bti-thunk=lfence'};
} else {
    ${$spec_ctrl_hash}{'bti-thunk=retpoline'} = ${$spec_ctrl_bti_thunk_retp_for_intel}{'bti-thunk=retpoline'};
}

my $tsx_hash = {};
if (get_var('FLAVOR', '') =~ /Haswell/i) {
    $tsx_hash = {%$tsx_off_for_haswell, %$tsx_on_for_haswell};
} else {
    $tsx_hash = {%$tsx_off_for_non_haswell, %$tsx_on_for_non_haswell};
}

my $pv_l1tf_hash = {%$pv_l1tf_false, %$pv_l1tf_true, %$pv_l1tf_dom0_false,
    %$pv_l1tf_dom0_true, %$pv_l1tf_domu_true, %$pv_l1tf_domu_false};

my $mitigations_list = {};
${$mitigations_list}{xpti} = $xpti_hash;
${$mitigations_list}{'spec-ctrl'} = $spec_ctrl_hash;
${$mitigations_list}{tsx} = $tsx_hash;
${$mitigations_list}{'pv-l1tf'} = $pv_l1tf_hash;

sub check_expected_string {
    my ($cmd, $lines) = @_;
    foreach my $expected_string (@{$lines}) {
        if ($expected_string ne "") {
            my $ret = script_run("$cmd | grep \"$expected_string\"");
            if ($ret ne 0) {
                record_info("ERROR", "Can't found a expected string.", result => 'fail');
                assert_script_run("xl dmesg | grep -A 10 \"Speculative\"");
                assert_script_run("xl info | grep -i \"xen_commandline\"");
                return 1;
            } else {
                #Debug what output be report.
                print "Got expected string, go on\n";
            }

        }
    }
    return 0;
}

sub check_unexpected_string {
    my ($cmd, $lines) = @_;
    foreach my $unexpected_string (@{$lines}) {
        if ($unexpected_string ne "") {
            my $ret = script_run("$cmd | grep \"$unexpected_string\"");
            if ($ret ne 0) {
                print "Not found unexpected string, go ahead";
            } else {
                #Debug what output be report.
                record_info("ERROR", "found a unexpected string.", result => 'fail');
                assert_script_run("xl dmesg | grep -A 10 \"Speculative\"");
                assert_script_run("xl info | grep -i \"xen_commandline\"");
                return 1;
            }
        }
    }
    return 0;
}

sub do_check {
    my $secnario = shift;
    my $foo = $secnario->{default};
    if ($foo->{expected}) {
        while (my ($cmd, $lines) = each %{$foo->{expected}}) {
            return 1 if check_expected_string($cmd, $lines) ne 0;
        }
    }
    if ($foo->{unexpected}) {
        while (my ($cmd, $lines) = each %{$foo->{unexpected}}) {
            return 1 if check_unexpected_string($cmd, $lines) ne 0;
        }
    }
    return 0;
}

sub do_test {
    my ($self, $hash) = @_;

    # Initialize variable for generating junit file
    my $testsuites_name = 'xen_hyper_mitigation';
    my $testsuite_name = '';
    my $testcase_name = '';
    my $total_failure_tc_count = 0;
    my $failure_tc_count_in_ts = 0;
    my $total_tc_count = 0;
    my $total_tc_count_in_ts = 0;
    my $junit_file = "/tmp/xen_hypervisor_mitigation_test_junit.xml";

    # user specify test suites to run, take "," as delimiter
    my $test_suites = get_var("TEST_SUITES", "");

    # Initialize junit sturcture for hypervisor mitigation test
    Mitigation::init_xml(file_name => "$junit_file", testsuites_name => "$testsuites_name");
    while (my ($arg, $dict) = each %$hash) {
        $failure_tc_count_in_ts = 0;
        $total_tc_count_in_ts = 0;

        # run user specifed test suite
        if ($test_suites and !grep { $_ eq $arg } split(/,+/, $test_suites)) {
            next;
        }
        # Add a group case name as testsuite to junit file
        Mitigation::append_ts2_xml(file_name => "$junit_file", testsuite_name => "$arg");

        # Start loop and execute all test cases
        while (my ($key, $value) = each %$dict) {
            my $parameter = $arg . '=' . $key;
            my $speculative_output = '';

            # Calculate test case count
            $total_tc_count += 1;
            $total_tc_count_in_ts += 1;

            # Set xen parameter to grub
            bootloader_setup::add_grub_xen_cmdline_settings($parameter, 1);
            Mitigation::reboot_and_wait($self, 150);

            record_info('INFO', "$parameter test is start.");
            my $ret = do_check($value);
            if ($ret ne 0) {
                # Calculate failure test case count
                $total_failure_tc_count += 1;
                $failure_tc_count_in_ts += 1;

                record_info('ERROR', "$parameter test is failed.", result => 'fail');
                # Collect speculative related output and insert current testcase into junit file
                $speculative_output = script_output("xl dmesg | grep -A 10 \"Speculative\"");
                Mitigation::insert_tc2_xml(file_name => "$junit_file", class_name => "$parameter", case_status => "fail", sys_output => '', sys_err => "$speculative_output");
            } else {
                Mitigation::insert_tc2_xml(file_name => "$junit_file", class_name => "$parameter", case_status => "pass");
            }
            # update testsuite into
            Mitigation::update_ts_attr(file_name => "$junit_file", attr => 'failures', value => $failure_tc_count_in_ts);
            Mitigation::update_ts_attr(file_name => "$junit_file", attr => 'tests', value => $total_tc_count_in_ts);
            # update testsuites info
            Mitigation::update_tss_attr(file_name => "$junit_file", attr => 'failures', value => $total_failure_tc_count);
            Mitigation::update_tss_attr(file_name => "$junit_file", attr => 'tests', value => $total_tc_count);
            # upload junit file for each case to avoid missing all result once test causes host hang.
            parse_junit_log("$junit_file");

            record_info('INFO', "$parameter test is finished.");
            # Restore to original gurb
            bootloader_setup::remove_grub_xen_cmdline_settings($parameter);
            bootloader_setup::grub_mkconfig();
        }
    }
    parse_junit_log("$junit_file");
}


sub run {
    my $self = @_;
    select_console 'root-console';
    die "platform mistake, This system is not running as Dom0." if script_run("test -d /proc/xen");
    zypper_call '--gpg-auto-import-keys ref';
    zypper_call 'in -y xmlstarlet expect';
    do_test($self, $mitigations_list);
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    script_run("xl info");
    upload_logs '/tmp/upload_mitigations.tar.bz2';
    script_run("rm -rf /tmp/upload_mitigations*");
    remove_grub_cmdline_settings('xpti=[a-z,]*');
    remove_grub_cmdline_settings('spec-ctrl=[a-z,-]*');
    remove_grub_cmdline_settings('pv-l1tf=[a-z,]*');
    grub_mkconfig;
}
1;
