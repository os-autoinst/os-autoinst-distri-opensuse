# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>
# Author: Di Kong <di.kong@suse.com>
#
# This testsuite for the mitigations control on XEN PV guest.
# And we will integrate HVM control flow here soon.
#
# We are testing each parameter. To check the influence of each one of them.
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
#
#  _________________________________________________      ___________________________________________________
# |Start/check the parameters in the mitigation_list| => |Input the parameter=value into the cmdline settings|
#  -------------------------------------------------     |Then grub_config and reboot.                       |
#                                                         ---------------------------------------------------
#                                                                               /\
#                                                                               ||
#                                                                               ||
#                                                                               ||
#                                                                               ||
#  _________________________________________              ______________________\/_________________________
# |Recall the infos after success or failure|   <======  |check the outcomes based on the value's key value|
#  -----------------------------------------              -------------------------------------------------
#                 /\
#                 ||
#                 ||
#                 ||
#                 ||
#  _______________\/_________________
# |Remove the cmdline and grub_config.|
# |And pick the next para=value.      |_____________________________________________________
# |When pick the last key value in a dic, jump to the next para and repeat the process above.|
#  -----------------------------------------------------------------------------------------
#
#
# Put into pti, l1tf, mds into this structure. and The testing code will read them all and
# one by one execution checking.
#

package xen_pv;
use strict;
use warnings;
use base "consoletest";
use bootloader_setup;
use Mitigation;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;

my $qa_password                 = get_required_var("QA_PASSWORD");
my $git_repo_url                = get_required_var("MITIGATION_GIT_REPO");
my $vm_domain_name              = get_required_var('VM_DOMAIN_NAME');
my $install_media_url           = get_required_var('INSTALL_MEDIA');
my $vm_install_kernel_parameter = get_required_var('VM_INSTALL_KERNEL_PARAMETER');
my $git_branch_name             = get_required_var("MITIGATION_GIT_BRANCH_NAME");
my $vm_ip_addr;
my $add_cmdline_settings = "mds=full";

my $mitigations_list = {
    l1tf => {
        full => {
            default => {
                expected => {'cat /proc/cmdline' => ['l1tf=full'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled']},
                unexpected => {'cat /proc/cmdline' => ['l1tf=full,force', 'l1tf=flush', 'l1tf=flush,nosmt', 'l1tf=flush,nowarn', 'l1tf=off'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable', 'Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: vulnerable']}
            }
        },
        "full,force" => {
            default => {
                expected => {'cat /proc/cmdline' => ['l1tf=full,force'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled']},
                unexpected => {'cat /proc/cmdline' => ['l1tf=full ', 'l1tf=flush', 'l1tf=flush,nosmt', 'l1tf=flush,nowarn', 'l1tf=off'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable', 'Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: vulnerable']}
            }
        },
        flush => {
            default => {
                expected => {'cat /proc/cmdline' => ['l1tf=flush'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['l1tf=full ', 'l1tf=full,force', 'l1tf=flush,nosmt', 'l1tf=flush,nowarn', 'l1tf=off'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: vulnerable']}
            }
        },
        "flush,nosmt" => {
            default => {
                expected => {'cat /proc/cmdline' => ['l1tf=flush,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled']},
                unexpected => {'cat /proc/cmdline' => ['l1tf=full ', 'l1tf=full,force', 'l1tf=flush ', 'l1tf=flush,nowarn', 'l1tf=off'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable', 'Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: vulnerable']}
            }
        },
        "flush,nowarn" => {
            default => {
                expected => {'cat /proc/cmdline' => ['l1tf=flush,nowarn'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['l1tf=full ', 'l1tf=full,force', 'l1tf=flush,nosmt', 'l1tf=flush ', 'l1tf=off'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: vulnerable']}
            }
        },
        off => {
            default => {
                expected => {'cat /proc/cmdline' => ['l1tf=off'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['l1tf=full ', 'l1tf=full,force', 'l1tf=flush,nosmt', 'l1tf=flush ', 'l1tf=flush,nowarn'], 'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled', 'Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable']}
            }
        },
    },
    pti => {
        on => {
            default => {
                expected   => {'cat /proc/cmdline' => ['pti=on'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI']},
                unexpected => {'cat /proc/cmdline' => ['pti=off', 'pti=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable']}
            }
        },
        off => {
            default => {
                expected   => {'cat /proc/cmdline' => ['pti=off'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['pti=on', 'pti=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI']}
            }
        },
        auto => {
            default => {
                expected   => {'cat /proc/cmdline' => ['pti=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI']},
                unexpected => {'cat /proc/cmdline' => ['pti=on', 'pti=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable']}
            }
        },
    },
    mds => {
        full => {
            default => {
                expected => {'cat /proc/cmdline' => ['mds=full'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['mds=full,nosmt', 'mds=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT disabled', 'Vulnerable; SMT vulnerable']}
            }
        },
        "full,nosmt" => {
            default => {
                expected => {'cat /proc/cmdline' => ['mds=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT disabled']},
                unexpected => {'cat /proc/cmdline' => ['mds=full ', 'mds=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT vulnerable', 'Vulnerable; SMT vulnerable']}
            }
        },
        off => {
            default => {
                expected => {'cat /proc/cmdline' => ['mds=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['mds=full', 'mds=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT vulnerable', 'Mitigation: Clear CPU buffers; SMT disabled']}
            }
        },
    },
    tsx_async_abort => {
        off => {
            default => {
                expected => {'cat /proc/cmdline' => ['tsx_async_abort=off'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=full', 'tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT vulnerable', 'Mitigation: Clear CPU buffers; SMT disable']}
            }
        },
        full => {
            default => {
                expected => {'cat /proc/cmdline' => ['tsx_async_abort=full'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT vulnerable']},
                unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT disable']}
            }
        },
        "full,nosmt" => {
            default => {
                expected => {'cat /proc/cmdline' => ['tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT disable']},
                unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full '], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT vulnerable']}
            }
        },
    },
    spectre_v2 => {
        on => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Full generic retpoline,.*IBPB: always-on, IBRS_FW, STIBP: forced.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=off', 'spectre_v2=auto', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled', 'Mitigation: Full generic retpoline,.*IBPB: conditional, IBRS_FW, STIBP: conditional,.*', 'Mitigation: Full generic retpoline.*']}
            }
        },
        off => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=off'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=auto', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Full generic retpoline,.*IBPB: always-on, IBRS_FW, STIBP: forced.*', 'Mitigation: Full generic retpoline,.*IBPB: conditional, IBRS_FW, STIBP: conditional,.*', 'Mitigation: Full generic retpoline.*']}
            }
        },
        auto => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Full generic retpoline,.*IBPB: conditional, IBRS_FW, STIBP: conditional,.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=off', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Full generic retpoline,.*IBPB: always-on, IBRS_FW, STIBP: forced.*', 'Vulnerable,.*IBPB: disabled,.*STIBP: disabled', 'Mitigation: Full generic retpoline.*']}
            }
        },
        retpoline => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Full generic retpoline.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=off', 'spectre_v2=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Full generic retpoline,.*IBPB: always-on, IBRS_FW, STIBP: forced.*', 'Vulnerable,.*IBPB: disabled,.*STIBP: disabled', 'Mitigation: Full generic retpoline,.*IBPB: conditional, IBRS_FW, STIBP: conditional,.*']}
            }
        },
    },
    spectre_v2_user => {
        on => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on,.* STIBP: forced,.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'IBPB: conditional,.* STIBP: conditional,.*']}
            }
        },
        off => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=off'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: disabled,.*STIBP: disabled']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: conditional.*STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'IBPB: conditional,.* STIBP: conditional,.*']}
            }
        },
        prctl => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=prctl'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: conditional.*STIBP: conditional.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: always-on.*STIBP: conditional.*', 'STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'IBPB: conditional,.* STIBP: conditional,.*']}
            }
        },
        "prctl,ibpb" => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=prctl,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on.*STIBP: conditional.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl ', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*STIBP: conditional.*', 'STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'IBPB: conditional,.* STIBP: conditional,.*']}
            }
        },
        seccomp => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=seccomp'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['STIBP: conditional.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'IBPB: conditional,.* STIBP: conditional,.*']}
            }
        },
        "seccomp,ibpb" => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=seccomp,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on.*STIBP: conditional.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp ', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'STIBP: conditional.*', 'IBPB: conditional,.* STIBP: conditional,.*']}
            }
        },
        auto => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: conditional,.* STIBP: conditional,.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2_user' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*', 'STIBP: conditional.*', 'IBPB: always-on.*STIBP: conditional.*']}
            }
        },
    },
};

sub do_check {
    my $secnario = shift;
    my $foo      = $secnario->{default};
    if ($foo->{expected}) {
        while (my ($cmd, $lines) = each %{$foo->{expected}}) {
            foreach my $expected_string (@{$lines}) {
                if ($expected_string ne "") {
                    my $ret = ssh_vm_cmd("$cmd | grep \"$expected_string\"");
                    record_info("ERROR", "Can't found a expected string.", result => 'fail') unless $ret eq 0;
                } else {
                    print "This expection is empty string, skip";
                }

            }
        }
    }
    if ($foo->{unexpected}) {
        while (my ($cmd, $lines) = each %{$foo->{unexpected}}) {
            foreach my $unexpected_string (@{$lines}) {
                if ($unexpected_string ne "") {
                    my $ret = ssh_vm_cmd("$cmd | grep \"$unexpected_string\"");
                    record_info("ERROR", "found a unexpected string.", result => 'fail') unless $ret ne 0;
                } else {
                    #Debug what output be report.
                    assert_script_run("xl dmesg | grep -A 10 \"Speculative\"");
                    print "This unexpection is empty string, skip";
                }

            }
        }
    }
}


sub config_and_reboot {
    ssh_vm_cmd("grub2-mkconfig -o /boot/grub2/grub.cfg");
    ssh_vm_cmd("poweroff");
    script_run('xl list');
    script_run("xl create \"${vm_domain_name}.cfg\"");
    script_run('echo Now I am waiting for the vm to reboot');
    script_run("sleep 60");
    ssh_vm_cmd("cat /proc/cmdline");
}

sub ssh_vm_cmd {
    my $cmd = shift;
    my $ret = script_run("sshpass -p ${qa_password} ssh -qy root\@${vm_ip_addr} $cmd");
    return $ret;
}

sub run {
    my $self = @_;
    select_console 'root-console';
    die "platform mistake, This system is not running as Dom0." if script_run("test -d /proc/xen");
    # 1. Prepare mitigations-testsuite.git and clean up the xp_worker.
    # xp_worker refers to XEN_PV_worker.
    assert_script_run("git config --global http.sslVerify false");
    assert_script_run("rm -rf mitigation-testsuite");
    assert_script_run("git clone -q --single-branch -b $git_branch_name --depth 1 $git_repo_url");
    assert_script_run("pushd mitigation-testsuite");
    assert_script_run("git status");
    assert_script_run("PAGER= git log -1");
    script_run('virsh undefine xp_worker');
    script_run('virsh destroy xp_worker');
    my $damn = script_run('virsh list --all | grep "xp_worker"');
    if ($damn eq 0) {
        record_info('fail', "The xp_worker hasn't been destroyed");
        die;
    }
    # 2. Create a VM
    script_run("virt-install --name \"${vm_domain_name}\" -p "
          . " --location \"${install_media_url}\""
          . " --extra-args \"${vm_install_kernel_parameter}\""
          . " --disk path=\"${vm_domain_name}\".\"disk\",size=20,format=qcow2"
          . " --network=bridge=br0"
          . " --memory=8192"
          . " --vcpu=8"
          . " --vnc"
          . " --events on_reboot=destroy"
          . " --serial pty", timeout => 3600);
    # 3. Start the VM and get the IP address of VM.
    script_run("virsh domxml-to-native xen-xl --domain ${vm_domain_name} > ${vm_domain_name}.cfg");
    script_run("xl create \"${vm_domain_name}.cfg\"");
    script_run('cd mitigation-testsuite');
    $vm_ip_addr = script_output(
        "export password=$testapi::password; ./get-ip-from-alive-guest.expect"
          . " \"${vm_domain_name}\"|"
          . " grep -E -o "
          . "\"=[[:digit:]]*\\.[[:digit:]]*\\.[[:digit:]]*\\.[[:digit:]]*=\" | tr -d \"=\"");
    #xen_pv_guest test parameter be stored into arg
    #$value include the check rules of current $parameter.
    # 4. Remove the mitigation=$parameter and check the test parameter in the mitigations_list
    ssh_vm_cmd("cat /proc/cmdline | grep \"mitigations=auto\"");
    ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/s/mitigations=[a-z,]*/\\ /' /etc/default/grub");
    config_and_reboot();
    while (my ($arg, $dict) = each %$mitigations_list) {
        while (my ($key, $value) = each %$dict) {
            my $parameter = $arg . '=' . $key;
            ssh_vm_cmd("sed -i -e 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"$parameter\"/' /etc/default/grub");
            config_and_reboot();
            my $ret = do_check($value);
            if ($ret ne 0) {
                record_info('ERROR', "$parameter test is failed.", result => 'fail');
            }
            record_info('INFO', "$parameter test is finished.");
            ssh_vm_cmd("sed -i -e 's/GRUB_CMDLINE_LINUX=\"$parameter\"/GRUB_CMDLINE_LINUX=\"\"/' /etc/default/grub");
            config_and_reboot();
        }
    }
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    script_run("xl info");
    upload_logs '/tmp/upload_mitigations.tar.bz2';
    script_run("rm -rf /tmp/upload_mitigations");
    script_run("rm -rf /tmp/upload_mitigations.tar.bz2");
    ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/pti=[a-z,]*/\\ /' /etc/default/grub");
    ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/l1tf=[a-z,]*/\\ /' /etc/default/grub");
    ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/mds=[a-z,]*/\\ /' /etc/default/grub");
    ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/tsx_async_abort=[a-z,]*/\\ /' /etc/default/grub");
    ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/spectre_v2=[a-z,]*/\\ /' /etc/default/grub");
    ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/spectre_v2_user=[a-z,]*/\\ /' /etc/default/grub");
    ssh_vm_cmd("grub2-mkconfig -o /boot/grub2/grub.cfg");
}
1;
