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

my $mitigations_list =
  {
    #command-line parameter name
    xpti => {
        #command-line the value of parameter.
        #It point to a array that include TWO elements.

        true => {
            default => {
                expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU enabled']},
                unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU disabled', 'XPTI (64-bit PV only): Dom0 disabled, DomU enabled', 'XPTI (64-bit PV only): Dom0 disabled, DomU disabled']}
            }
        },
        false => {
            default => {
                expected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 disabled, DomU disabled']},
                unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU disabled', 'XPTI (64-bit PV only): Dom0 enabled, DomU enabled', 'XPTI (64-bit PV only): Dom0 disabled, DomU enabled']}
            }
        },
        "dom0=true" => {
            default => {
                expected   => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU .*$']},
                unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 disabled, DomU .*$']}
            }
        },
        "dom0=false" => {
            default => {
                expected   => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 disabled, DomU .*$']},
                unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 enabled, DomU .*$']}
            }
        },
        "domu=true" => {
            default => {
                expected   => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU enabled']},
                unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU disabled']}
            }
        },
        "domu=false" => {
            default => {
                expected   => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU disabled']},
                unexpected => {'xl dmesg' => ['XPTI (64-bit PV only): Dom0 .*, DomU enabled']}
            }
        },

    },
    'spec-ctrl' => {
        #command-line the value of parameter.
        #It point to a array that include TWO elements.
        #
        no => {
            default => {
                #expection string. If it doesn't appear go die
                expected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk JMP, SPEC_CTRL: IBRS- SSBD-.*, Other:$',
'Support for HVM VMs: MD_CLEAR', 'Support for PV VMs: MD_CLEAR', '^(XEN)   XPTI (64-bit PV only): Dom0 disabled, DomU disabled (with PCID)$', '^(XEN)   PV L1TF shadowing: Dom0 disabled, DomU disabled$']},
                #unexpection string. If it appears go die.
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "no-xen" => {
            default => {
                expected   => {'xl dmesg' => ['Xen settings: BTI-Thunk JMP, SPEC_CTRL: IBRS- SSBD-.*, Other:$']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "pv=on" => {
            default => {
                expected   => {'xl dmesg' => ['Support for PV VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "pv=0" => {
            default => {
                expected   => {'xl dmesg' => ['Support for PV VMs: EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "hvm=on" => {
            default => {
                expected   => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "hvm=0" => {
            default => {
                expected   => {'xl dmesg' => ['Support for HVM VMs: EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "msr-sc=on" => {
            default => {
                expected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR', 'Support for PV VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "msr-sc=off" => {
            default => {
                expected   => {'xl dmesg' => ['Support for HVM VMs: RSB EAGER_FPU MD_CLEAR', 'Support for PV VMs: RSB EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "rsb=on" => {
            default => {
                expected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR', 'Support for PV VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "rsb=off" => {
            default => {
                expected   => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL EAGER_FPU MD_CLEAR', 'Support for PV VMs: MSR_SPEC_CTRL EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "md-clear=off" => {
            default => {
                #even md-clear=off
                expected   => {'xl dmesg' => ['Support for HVM VMs: .*MD_CLEAR', 'Support for PV VMs: .*MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "md-clear=on" => {
            default => {
                expected   => {'xl dmesg' => ['Support for HVM VMs: .*MD_CLEAR', 'Support for PV VMs: .*MD_CLEAR']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "bti-thunk=retpoline" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk RETPOLINE, SPEC_CTRL: IBRS+ SSBD-.*, Other:']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "bti-thunk=lfence" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk LFENCE, SPEC_CTRL: IBRS+ SSBD-.*, Other:']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "bti-thunk=jmp" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk JMP, SPEC_CTRL: IBRS+ SSBD-.*, Other:']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "ibrs=off" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS- SSBD-.*, Other:']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "ibrs=on" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS+ SSBD-.*, Other:']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "ibpb=off" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other:']},
                unexpected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other:.*IBPB']}
            }
        },
        "ibpb=on" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: IBPB']},
                unexpected => {'xl dmesg' => ['']}
            }
        },
        "ssbd=off" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other:']},
                unexpected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD+, Other:']}
            }
        },
        "ssbd=on" => {
            default => {
                expected   => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD+, Other:']},
                unexpected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other:']}
            }
        },
        "eager-fpu=off" => {
            default => {
                expected   => {'xl dmesg' => ['Support for .* VMs: MSR_SPEC_CTRL RSB MD_CLEAR']},
                unexpected => {'xl dmesg' => ['Support for .* VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']}
            }
        },
        "eager-fpu=on" => {
            default => {
                expected   => {'xl dmesg' => ['Support for .* VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
                unexpected => {''},
            }
        },
        "l1d-flush=off" => {
            default => {
                expected   => {''},
                unexpected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: .*L1D_FLUSH']},
            }
        },
        "l1d-flush=on" => {
            default => {
                expected   => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: .*L1D_FLUSH']},
                unexpected => {''},
            }
        },
        "branch-harden=on" => {
            default => {
                expected   => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: .*BRANCH_HARDEN']},
                unexpected => {''},
            }
        },
        "branch-harden=off" => {
            default => {
                expected   => {''},
                unexpected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: .*BRANCH_HARDEN']},
            },
        },
        #FIXME
        #Haswell-noTSX platform wouldn't display TSX flag, should be ignore it when test run is failed.
        "tsx=off" => {
            default => {
                expected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: .*TSX-, Other:.*'],
                    'xl info' => ['tsx=off']},
                unexpected => {'xl dmesg' => ['']},
            }
        },
        "tsx=on" => {
            default => {
                expected => {'xl dmesg' => ['Xen settings: BTI-Thunk .*, SPEC_CTRL: .*TSX+, Other:.*'],
                    'xl info' => ['tsx=on']},
                unexpected => {''},
            }
        },
    }
  };


sub check_expected_string {
    my ($cmd, $lines) = @_;
    assert_script_run("xl dmesg | grep -A 10 \"Speculative\"");
    assert_script_run("xl info | grep -i \"xen_commandline\"");
    foreach my $expected_string (@{$lines}) {
        if ($expected_string ne "") {
            my $ret = script_run("$cmd | grep \"$expected_string\"");
            if ($ret ne 0) {
                record_info("ERROR", "Can't found a expected string.", result => 'fail');
                if ($cmd =~ /xl.*info/) {
                    assert_script_run("$cmd");
                }
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
    assert_script_run("xl dmesg | grep -A 10 \"Speculative\"");
    foreach my $unexpected_string (@{$lines}) {
        if ($unexpected_string ne "") {
            my $ret = script_run("$cmd | grep \"$unexpected_string\"");
            if ($ret ne 0) {
                print "Not found unexpected string, go ahead";
            } else {
                #Debug what output be report.
                record_info("ERROR", "found a unexpected string.", result => 'fail');
                return 1;
            }
        }
    }
    return 0;
}

sub do_check {
    my $secnario = shift;
    my $foo      = $secnario->{default};
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
    my $testsuites_name        = 'xen_hyper_mitigation';
    my $testsuite_name         = '';
    my $testcase_name          = '';
    my $total_failure_tc_count = 0;
    my $failure_tc_count_in_ts = 0;
    my $total_tc_count         = 0;
    my $total_tc_count_in_ts   = 0;
    my $junit_file             = "/tmp/xen_hypervisor_mitigation_test_junit.xml";

    # Initialize junit sturcture for hypervisor mitigation test
    Mitigation::init_xml(file_name => "$junit_file", testsuites_name => "$testsuites_name");
    while (my ($arg, $dict) = each %$hash) {
        $failure_tc_count_in_ts = 0;
        $total_tc_count_in_ts   = 0;

        # Add a group case name as testsuite to junit file
        Mitigation::append_ts2_xml(file_name => "$junit_file", testsuite_name => "$arg");

        # Start loop and execute all test cases
        while (my ($key, $value) = each %$dict) {
            my $parameter          = $arg . '=' . $key;
            my $speculative_output = '';

            # Calculate test case count
            $total_tc_count       += 1;
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
            Mitigation::update_ts_attr(file_name => "$junit_file", attr => 'tests',    value => $total_tc_count_in_ts);
            # update testsuites info
            Mitigation::update_tss_attr(file_name => "$junit_file", attr => 'failures', value => $total_failure_tc_count);
            Mitigation::update_tss_attr(file_name => "$junit_file", attr => 'tests',    value => $total_tc_count);
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
