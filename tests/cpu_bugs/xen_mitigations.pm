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
                unexpected => {'xl dmesg' => ['^(XEN) *Xen settings: BTI-Thunk .*, SPEC_CTRL: IBRS. SSBD-.*, Other: IBPB']}
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
                expected   => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB MD_CLEAR']},
                unexpected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']}
            }
        },
        "eager-fpu=on" => {
            default => {
                expected   => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB EAGER_FPU MD_CLEAR']},
                unexpected => {'xl dmesg' => ['Support for HVM VMs: MSR_SPEC_CTRL RSB MD_CLEAR']}
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
    foreach my $expected_string (@{$lines}) {
        if ($expected_string ne "") {
            my $ret = script_run("$cmd | grep \"$expected_string\"");
            if ($ret ne 0) {
                record_info("ERROR", "Can't found a expected string.", result => 'fail');
                assert_script_run("$cmd | grep -A 10 \"Speculative\"");
            } else {
                #Debug what output be report.
                assert_script_run("xl dmesg | grep -A 10 \"Speculative\"");
                print "This unexpection is empty string, skip";

            }

        }
    }
}
sub check_unexpected_string {
    my ($cmd, $lines) = @_;
    foreach my $unexpected_string (@{$lines}) {
        if ($unexpected_string ne "") {
            my $ret = script_run("$cmd | grep \"$unexpected_string\"");
            record_info("ERROR", "found a unexpected string.", result => 'fail') unless $ret ne 0;
            assert_script_run("$cmd | grep -A 10 \"Speculative\"");
        } else {
            #Debug what output be report.
            assert_script_run("xl dmesg | grep -A 10 \"Speculative\"");
            print "This unexpection is empty string, skip";
        }

    }

}
sub do_check {
    my $secnario = shift;
    my $foo      = $secnario->{default};
    if ($foo->{expected}) {
        while (my ($cmd, $lines) = each %{$foo->{expected}}) {
            check_expected_string($cmd, $lines);
        }
    }
    if ($foo->{unexpected}) {
        while (my ($cmd, $lines) = each %{$foo->{unexpected}}) {
            check_unexpected_string($cmd, $lines);
        }
    }
}

sub do_test {
    my ($self, $hash) = @_;
    #xen parameter be store into arg
    #
    while (my ($arg, $dict) = each %$hash) {
        while (my ($key, $value) = each %$dict) {
            my $parameter = $arg . '=' . $key;
            bootloader_setup::add_grub_xen_cmdline_settings($parameter);
            bootloader_setup::grub_mkconfig();
            Mitigation::reboot_and_wait($self, 150);
            #$value include the check rules of current $parameter.
            record_info('INFO', "$parameter test is start.");
            my $ret = do_check($value);
            if ($ret ne 0) {
                record_info('ERROR', "$parameter test is failed.", result => 'fail');
            }
            record_info('INFO', "$parameter test is finished.");
            bootloader_setup::remove_grub_xen_cmdline_settings($parameter);
            bootloader_setup::grub_mkconfig();
        }

    }
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
