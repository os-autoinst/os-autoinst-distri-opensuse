# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# KVM Guest mitigations test include mitigations=auto/off/auto,nosmt

# Summary: CPU BUGS on Linux kernel check
# Maintainer: Qi Wang <qwang@suse.com>
package kvm_guest_mitigations;
use strict;
use warnings;
use base "consoletest";
use bootloader_setup;
use Mitigation;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;
use bmwqemu;
use Data::Dumper;
use Mitigation;
our $CPU_MODE = get_required_var("CPUMODE");
my $qa_password = get_var("QA_PASSWORD", "nots3cr3t");
my $install_media_url = get_required_var('INSTALL_MEDIA');
my $hostmitigation = get_required_var('HOSTMITIGATION');
my $guest_name = get_var('GUEST_NAME');
my $extra_guest_kernel_param = get_required_var('EXTRA_KERNEL_PARAMETER_FOR_GUEST');
if (!$guest_name) {
    $guest_name = "kvm_" . "$CPU_MODE" . "_guest";
}
my $guest_imagepool_path = "/kvm_" . "$CPU_MODE";
my $guest_ip_addr;

#Skylake configuration
my $mitigations_auto_on_skylake_passthrough = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS, IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: flush not necessary, SMT disabled']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_on_custom = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines,.*IBPB: conditional, IBRS_FW*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['KVM: Mitigation: VMX unsupported'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_nosmt_on_skylake_passthrough = {"mitigations=auto,nosmt" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto,nosmt'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS, IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: flush not necessary, SMT disabled']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_nosmt_on_custom = {"mitigations=auto,nosmt" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto,nosmt'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines,.*IBPB: conditional, IBRS_FW*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['KVM: Mitigation: VMX unsupported'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion']},
            unexpected => {}
        }
    }
};
my $mitigations_off_on_skylake_passthrough = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Vulnerable: __user pointer sanitization and usercopy barriers only; no swapgs barriers'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion; VMX: flush not necessary, SMT disabled']},
            unexpected => {}
        }
    }
};
my $mitigations_off_on_custom = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['KVM: Mitigation: VMX unsupported'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Vulnerable: __user pointer sanitization and usercopy barriers only; no swapgs barriers'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Mitigation: PTE Inversion']},
            unexpected => {}
        }
    }
};
#Icelake configuration
my $mitigations_auto_on_icelake_passthrough = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Enhanced IBRS, IBPB: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_nosmt_on_icelake_passthrough = {"mitigations=auto,nosmt" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto,nosmt'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Enhanced IBRS, IBPB: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_off_on_icelake_passthrough = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Vulnerable: __user pointer sanitization and usercopy barriers only; no swapgs barriers'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Not affected']},
            unexpected => {}
        }
    }
};

#Cascadelake configuration
my $mitigations_auto_on_cascadelake_passthrough = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Enhanced IBRS, IBPB: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_nosmt_on_cascadelake_passthrough = {"mitigations=auto,nosmt" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto,nosmt'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Enhanced IBRS, IBPB: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Mitigation: Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Mitigation: usercopy/swapgs barriers and __user pointer sanitization'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_off_on_cascadelake_passthrough = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Not affected'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/itlb_multihit' => ['Not affected'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v1' => ['Vulnerable: __user pointer sanitization and usercopy barriers only; no swapgs barriers'],
                'cat /sys/devices/system/cpu/vulnerabilities/l1tf' => ['Not affected']},
            unexpected => {}
        }
    }
};
#Check the Host Mitigations Setting
sub HostMitigation {
    my $self = @_;
    my $ret = script_run("grep 'mitigations=$hostmitigation' /proc/cmdline");

    if ($ret eq 0) {
        record_info("Host mitigation=$hostmitigation");
    }
    else {
        my $ret1 = script_run('grep "' . "mitigations" . '=[a-z,]*" /proc/cmdline');
        if ($ret1 eq 0) {
            remove_grub_cmdline_settings("mitigations=[a-z,]*");
            add_grub_cmdline_settings("mitigations=" . $hostmitigation);
            grub_mkconfig();
            Mitigation::reboot_and_wait($self, 150);
        } else {
            add_grub_cmdline_settings("mitigations=" . $hostmitigation);
            grub_mkconfig();
            Mitigation::reboot_and_wait($self, 150);
        }
    }
}
sub install_guest {
    my $self = @_;
    my $guest_intall_param = '';
    script_run("virsh destroy \"${guest_name}\"");
    script_run("virsh  undefine --remove-all-storage \"${guest_name}\"");
    if (script_run("ls $guest_imagepool_path | grep ${guest_name}.disk") ne 0 or
        script_run("virsh list --all | grep \"${guest_name}\"") ne 0) {
        script_run("rm -rf $guest_imagepool_path");
        script_run("mkdir $guest_imagepool_path");
        script_run("qemu-img create -f qcow2 $guest_imagepool_path/${guest_name}.disk 20G");

        if ($CPU_MODE =~ /passthrough/i) {
            $guest_intall_param = "host-passthrough";
        } else {
            $guest_intall_param = "Broadwell-noTSX,+spec-ctrl,+md-clear,+ssbd";
        }
        my $status = script_output("virt-install --name \"${guest_name}\" "
              . " --cpu \"$guest_intall_param\""
              . " --location \"${install_media_url}\""
              . " --extra-args ${extra_guest_kernel_param}"
              . " --disk path=${guest_imagepool_path}/${guest_name}.disk,size=20,format=qcow2"
              . " --network=bridge=br0,model=virtio"
              . " --memory=1024"
              . " --vcpu=2"
              . " --vnc"
              . " --wait 180"
              . " --noautoconsole"
              . " --events on_reboot=destroy"
              . " --serial pty", timeout => 5400);
        if ($status =~ /Domain is still running. Installation may be in progress/) {
            diag "Guest installation successful.\n";

        } else {
            diag "Error:guest installation,Please check the status of guest.\n";
            return 0;
        }
    }


    # Check if the guest is running
    script_run("virsh start \"${guest_name}\"");
    return 1;
}
sub get_expect_script {
    my $self = @_;
    my $expect_script_name = 'get_guest_ip.sh';
    assert_script_run("curl -s -o ~/$expect_script_name " . data_url("mitigation/xen/$expect_script_name"));
    assert_script_run("chmod a+x " . $expect_script_name);
}
sub get_guest_ip {
    return script_output("./get_guest_ip.sh \"${guest_name}\"", timeout => 3600);
}


# TODO TEST variables
my $mitigations = {};

if ($bmwqemu::vars{MICRO_ARCHITECTURE} =~ /Skylake/i) {
    if ($kvm_guest_mitigations::CPU_MODE =~ /passthrough/) {
        $mitigations = {%$mitigations_auto_on_skylake_passthrough, %$mitigations_auto_nosmt_on_skylake_passthrough, %$mitigations_off_on_skylake_passthrough};
    } elsif ($CPU_MODE =~ /custom/) {
        $mitigations = {%$mitigations_auto_on_custom, %$mitigations_auto_nosmt_on_custom, %$mitigations_off_on_custom};
    }
} elsif ($bmwqemu::vars{MICRO_ARCHITECTURE} =~ /Icelake/i) {
    if ($kvm_guest_mitigations::CPU_MODE =~ /passthrough/) {
        $mitigations = {%$mitigations_auto_on_icelake_passthrough, %$mitigations_auto_nosmt_on_icelake_passthrough, %$mitigations_off_on_icelake_passthrough};
    } elsif ($CPU_MODE =~ /custom/) {
        $mitigations = {%$mitigations_auto_on_custom, %$mitigations_auto_nosmt_on_custom, %$mitigations_off_on_custom};
    }
} else {
    if ($kvm_guest_mitigations::CPU_MODE =~ /passthrough/) {
        $mitigations = {%$mitigations_auto_on_cascadelake_passthrough, %$mitigations_auto_nosmt_on_cascadelake_passthrough, %$mitigations_off_on_cascadelake_passthrough};
    } elsif ($CPU_MODE =~ /custom/) {
        $mitigations = {%$mitigations_auto_on_custom, %$mitigations_auto_nosmt_on_custom, %$mitigations_off_on_custom};
    }
}
my $mitigations_test = {
    mitigations => $mitigations,
};
sub exec_testcases {
    my $self = @_;
    Mitigation::ssh_vm_cmd("cat /proc/cmdline | grep   \"mitigations=auto\"", $qa_password, $guest_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/s/mitigations=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $guest_ip_addr);
    Mitigation::config_and_reboot($qa_password, $guest_name, $guest_ip_addr);
    # Loop to execute test accounding to hash list
    my $kvm_test_cases_hash = {};
    $kvm_test_cases_hash = $mitigations_test;

    script_run("virsh start \"${guest_name}\"");
    record_info("Info", "Waiting for the vm up to go ahead ", result => 'ok');
    sleep 60;

    Mitigation::guest_cycle_kvm($self, $kvm_test_cases_hash, 'all', $qa_password, $guest_name, $guest_ip_addr);


}



sub check_and_run {
    my $guest_status = install_guest();
    if ($guest_status == 1) {
        $guest_ip_addr = get_guest_ip();
        if ($guest_ip_addr =~ /Error/) {
            diag "Get guest ip address fail\n";
        } else {
            diag "Begin execute testcase.\n";
            exec_testcases();
        }
    } else {
        die "Installation guest failed.";
    }
}
sub run {
    my $self = @_;
    select_console 'root-console';
    die "platform mistake, This system is not running on kvm" if script_run("lsmod |grep kvm");
    my $qa_repo_url = get_var("QA_REPO_RUL", "http://dist.suse.de/ibs/QA:/Head/SLE-15-SP2/");
    zypper_ar($qa_repo_url, name => 'qa-head');
    zypper_call '--gpg-auto-import-keys ref';
    zypper_call 'in -y xmlstarlet expect sshpass';
    HostMitigation();
    get_expect_script();
    check_and_run();
}
sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
}
1;
