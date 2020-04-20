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

package xen_hvm;
use strict;
use warnings;
use base "consoletest";
use bootloader_setup;
use Mitigation;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;

my $qa_password                     = get_required_var("QA_PASSWORD");
my $git_repo_url                    = get_required_var("MITIGATION_GIT_REPO");
my $hvm_domain_name                 = get_var('HVM_DOMAIN_NAME');
my $install_media_url               = get_required_var('INSTALL_MEDIA');
my $hvm_vm_install_kernel_parameter = get_required_var('HVM_VM_INSTALL_KERNEL_PARAMETER');
my $git_branch_name                 = get_required_var("MITIGATION_GIT_BRANCH_NAME");
my $hvm_test_mode                   = get_required_var('HVM_TEST_MODE');
my $hvm_single_test                 = get_required_var('HVM_SINGLE_TEST');
my $vm_ip_addr;
my $add_cmdline_settings = "mds=full";
my $vm_domain_name;
my $complete_cmd;
my $hvm_imagepool_path = "/xen_hvm";

my $hypervisor_mitigations_list = {
    'spec-ctrl' => {
        #This is hypervisor fully disable situation.
        no => {
            default => {
                nextmove => {'donothing'}
            }
        },
        #This is hypervisor no-xen situation.
        "no-xen" => {
            default => {
                nextmove => {'donothing'}
            }
        },
        #This is hypervisor default enable situation.
        yes => {
            default => {
                nextmove => {'donothing'}
            }
        }
    }
};

my $hvm_guest_mitigations_list = {
    mds => {
        full => {
            default => {
                expected => {'cat /proc/cmdline' => ['mds=full'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
                unexpected => {'cat /proc/cmdline' => ['mds=full,nosmt', 'mds=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown']}
            }
        },
        "full,nosmt" => {
            default => {
                expected => {'cat /proc/cmdline' => ['mds=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
                unexpected => {'cat /proc/cmdline' => ['mds=full ', 'mds=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown']}
            }
        },
    },
    tsx_async_abort => {
        full => {
            default => {
                expected => {'cat /proc/cmdline' => ['tsx_async_abort=full'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
                unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT disable']}
            }
        },
        "full,nosmt" => {
            default => {
                expected => {'cat /proc/cmdline' => ['tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
                unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full '], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT vulnerable']}
            }
        },
    },
    spectre_v2 => {
        on => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=off', 'spectre_v2=auto', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional,.*IBRS_FW,.*RSB filling']}
            }
        },
        off => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=off'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=auto', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced.*', 'IBPB: conditional,.*IBRS_FW,.*RSB filling']}
            }
        },
        auto => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional,.*IBRS_FW,.*RSB filling']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=off', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced.*', 'Vulnerable,.*IBPB: disabled,.*STIBP: disabled']}
            }
        },
        retpoline => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional,.*IBRS_FW,.*RSB filling']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=off', 'spectre_v2=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced.*', 'Vulnerable,.*IBPB: disabled,.*STIBP: disabled']}
            }
        },
    },
    spectre_v2_user => {
        on => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*']}
            }
        },
        off => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=off'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: disabled,.*STIBP: disabled']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: conditional.*', 'IBPB: always-on.*']}
            }
        },
        prctl => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=prctl'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: always-on.*']}
            }
        },
        "prctl,ibpb" => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=prctl,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl ', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*']}
            }
        },
        seccomp => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=seccomp'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: always-on.*']}
            }
        },
        "seccomp,ibpb" => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=seccomp,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp ', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*']}
            }
        },
        auto => {
            default => {
                expected => {'cat /proc/cmdline' => ['spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional.*']},
                unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: always-on.*']}
            }
        },
    },
};

sub hvm_check {
    my $self = @_;
    # 1. Make the xh_worker ready.
    # xh_worker refers to XEN_hvm_worker.
    script_run("virsh destroy \"${hvm_domain_name}\"");
    script_run("virsh undefine \"${hvm_domain_name}\"");
    script_run("xl destroy \"${hvm_domain_name}\"");
    my $damn = script_run("ls ${hvm_imagepool_path} | grep \"${hvm_domain_name}.disk\"");
    if ($damn eq 0) {
        record_info('stand by', "VM image is existed import it for more faster install. (Fastpath)....");
        #Install hvm guest via import a exist disk
        script_run("virt-install --name \"${hvm_domain_name}\" --import -v "
              . " --disk path=${hvm_imagepool_path}/${hvm_domain_name}.disk,size=20,format=qcow2"
              . " --os-variant auto"
              . " --network=bridge=br0"
              . " --memory=8192"
              . " --vcpu=8"
              . " --vnc"
              . " --noautoconsole"
              . " --wait 0", timeout => 3600);
    }
    # Create a hvm VM
    else {
        script_run("rm -rf ${hvm_imagepool_path}");
        script_run("mkdir ${hvm_imagepool_path}");
        script_run("qemu-img create -f qcow2 ${hvm_imagepool_path}/\"${hvm_domain_name}\".disk 20G");
        script_run("virt-install --name \"${hvm_domain_name}\" -v "
              . " --location \"${install_media_url}\""
              . " --extra-args \"console=ttyS0,115200n8 ${hvm_vm_install_kernel_parameter} debug ignore_loglevel\""
              . " --disk path=${hvm_imagepool_path}/\"${hvm_domain_name}\".disk,size=20,format=qcow2"
              . " --network=bridge=br0"
              . " --memory=8192"
              . " --vcpu=8"
              . " --vnc"
              . " --events on_reboot=destroy"
              . " --serial pty", timeout => 3600);
    }
    # 2. Start the hvm VM and get the IP address of VM.
    $damn = script_run("virsh list | grep \"${hvm_domain_name}.*running\"");
    if ($damn eq 0) {
        script_run("echo \"${hvm_domain_name}\" has been active");
    }
    else {
        script_run("virsh start \"${hvm_domain_name}\"");
    }
    script_run("./is_guest_up.expect"
          . " \"${hvm_domain_name}\"", timeout => 3600);
    script_run('\r\n');
    #May appear some random numbers. Need to be improved.
    $vm_ip_addr = script_output(
        "export password=$qa_password; ./get-ip-from-alive-xen-guest.expect"
          . " \"${hvm_domain_name}\"|"
          . " grep -E -o "
          . "\"=[[:digit:]]*\\.[[:digit:]]*\\.[[:digit:]]*\\.[[:digit:]]*=\" | tr -d \"=\"");
    script_run('\r\n');
    #xen_hvm_guest test parameter be stored into arg
    #$value include the check rules of current $parameter.
    # 3. Remove the mitigation=$parameter and check the test parameter in the mitigations_list
    Mitigation::ssh_vm_cmd("cat /proc/cmdline | grep \"mitigations=auto\"",                                      $qa_password, $vm_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/s/mitigations=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $vm_ip_addr);
    $vm_domain_name = get_required_var('HVM_DOMAIN_NAME');
    Mitigation::config_and_reboot($qa_password, $hvm_domain_name, $vm_ip_addr);
    while (my ($hvm_hyparg, $hvm_hypdict) = each %$hypervisor_mitigations_list) {
        while (my ($hvm_hypkey, $hvm_hypvalue) = each %$hvm_hypdict) {
            my $hvm_hyp_parameter = $hvm_hyparg . '=' . $hvm_hypkey;
            my $hvm_hypfoo        = $hvm_hypvalue->{default};
            $complete_cmd = $hvm_hyp_parameter;
            if ($hvm_test_mode eq 'single') {
                if ($hvm_hypkey eq 'yes') {
                    script_run("sed -i -e 's/GRUB_CMDLINE_LINUX=\\\"\\\"/GRUB_CMDLINE_LINUX=\\\"$complete_cmd\\\"/' /etc/default/grub");
                    bootloader_setup::grub_mkconfig();
                    Mitigation::reboot_and_wait($self, 150);
                    script_run("virsh start \"${hvm_domain_name}\"");
                    script_run('echo Now I am waiting for the vm to go into the first loop');
                    script_run("sleep 60");
                    hvm_guest_single($self, $hvm_guest_mitigations_list, $hvm_single_test, $hvm_test_mode, $qa_password, $hvm_domain_name, $vm_ip_addr);
                    script_run("sed -i -e 's/GRUB_CMDLINE_LINUX=\\\"$complete_cmd\\\"/GRUB_CMDLINE_LINUX=\\\"\\\"/' /etc/default/grub");
                    bootloader_setup::grub_mkconfig();
                }
            }
            if ($hvm_test_mode eq 'all') {
                script_run("sed -i -e 's/GRUB_CMDLINE_LINUX=\\\"\\\"/GRUB_CMDLINE_LINUX=\\\"$complete_cmd\\\"/' /etc/default/grub");
                bootloader_setup::grub_mkconfig();
                Mitigation::reboot_and_wait($self, 150);
                script_run("virsh start \"${hvm_domain_name}\"");
                script_run('echo Now I am waiting for the hvm_vm to reboot and go into the first loop');
                script_run("sleep 60");
                Mitigation::guest_cycle($self, $hvm_guest_mitigations_list, $hvm_single_test, $hvm_test_mode, $qa_password, $hvm_domain_name, $vm_ip_addr);
                Mitigation::mds_taa_check($qa_password, $hvm_domain_name, $vm_ip_addr);
                Mitigation::pti_check($qa_password, $hvm_domain_name, $vm_ip_addr);
                script_run("sed -i -e 's/GRUB_CMDLINE_LINUX=\\\"$complete_cmd\\\"/GRUB_CMDLINE_LINUX=\\\"\\\"/' /etc/default/grub");
                bootloader_setup::grub_mkconfig();
            }
        }
    }
}

sub hvm_guest_single {
    my ($self, $hvm_guest_mitigations_list, $hvm_single_test, $hvm_test_mode, $qa_password, $hvm_domain_name, $vm_ip_addr) = @_;
    if ($hvm_single_test eq 'mds_taa') {
        Mitigation::mds_taa_check($qa_password, $hvm_domain_name, $vm_ip_addr);
    }
    if ($hvm_single_test eq 'pti') {
        Mitigation::pti_check($qa_password, $hvm_domain_name, $vm_ip_addr);
    }
    else {
        Mitigation::guest_cycle($self, $hvm_guest_mitigations_list, $hvm_single_test, $hvm_test_mode, $qa_password, $hvm_domain_name, $vm_ip_addr);
    }
}

sub run {
    my $self = @_;
    select_console 'root-console';
    die "platform mistake, This system is not running as Dom0." if script_run("test -d /proc/xen");
    # 1. Prepare mitigations-testsuite.git
    assert_script_run("git config --global http.sslVerify false");
    assert_script_run("rm -rf mitigation-testsuite");
    assert_script_run("git clone -q --single-branch -b $git_branch_name --depth 1 $git_repo_url");
    assert_script_run("pushd mitigation-testsuite");
    assert_script_run("git status");
    assert_script_run("PAGER= git log -1");
    hvm_check();
}

sub post_fail_hook {
    my ($self) = @_;
    my $hvm_vm_ip_addr = script_output(
        "export password=$qa_password; ./get-ip-from-alive-xen-guest.expect"
          . " \"${hvm_domain_name}\"|"
          . " grep -E -o "
          . "\"=[[:digit:]]*\\.[[:digit:]]*\\.[[:digit:]]*\\.[[:digit:]]*=\" | tr -d \"=\"");
    select_console 'root-console';
    script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    script_run("xl info");
    upload_logs '/tmp/upload_mitigations.tar.bz2';
    script_run("rm -rf /tmp/upload_mitigations");
    script_run("rm -rf /tmp/upload_mitigations.tar.bz2");
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/l1tf=[a-z,]*/\\ /' /etc/default/grub",            $qa_password, $hvm_vm_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/pti=[a-z,]*/\\ /' /etc/default/grub",             $qa_password, $hvm_vm_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/tsx_async_abort=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_vm_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/mds=[a-z,]*/\\ /' /etc/default/grub",             $qa_password, $hvm_vm_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/spectre_v2_user=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_vm_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/spectre_v2=[a-z,]*/\\ /' /etc/default/grub",      $qa_password, $hvm_vm_ip_addr);
    Mitigation::ssh_vm_cmd("grub2-mkconfig -o /boot/grub2/grub.cfg",                                         $qa_password, $hvm_vm_ip_addr);
}
1;
