# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: KVM Guest install under the mitigation enable/disable
# Maintainer: James Wang <jnwang@suse.com>

use strict;
use warnings;
use base "consoletest";
use Mitigation;
use bootloader_setup;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use lockapi;
use utils;
use mmapi;

my $syspath = '/sys/devices/system/cpu/vulnerabilities/';
my $name = get_var('VM_NAME');
my $install_url = get_var('INSTALL_REPO');
my $logfile_path = get_var('VM_INST_LOG');
my $cpu = get_var('CPU_FEATURE');
my $vm_pool = get_var('VM_POOL');
my $vm_shares = get_var('VM_SHARES');
my $source_host = get_var("SOURCE_HOSTNAME");
my $dest_host = get_var("DEST_HOSTNAME");
my $subname = "";
my $cpu_1 = "";


sub check_working_status {
    return script_run("grep \'^1\$\' ${vm_pool}/flag");
}
sub check_idle_status {
    return script_run("grep \'^0\$\' ${vm_pool}/flag");
}
sub goto_work {
    assert_script_run("echo \"1\" > ${vm_pool}/flag;sync ${vm_pool}/flag");
}
sub jobs_done {
    assert_script_run("echo \"0\" > ${vm_pool}/flag;sync ${vm_pool}/flag");
}
sub remove_old_vm {
    assert_script_run(
        'curl '
          . data_url("cpu_bugs/vm_install_script/sle-15/remove_vm.sh")
          . ' -o remove_vm.sh',
        60
    );
    assert_script_run('chmod 755 remove_vm.sh');
    script_run('./remove_vm.sh' . ' ' . $name . '-' . $subname);
}

sub create_new_vm {
    assert_script_run(
        "qemu-img create -f qcow2 -b ${vm_pool}/${name}.qcow2 ${vm_pool}/${name}-${subname}.qcow2"
    );
    assert_script_run(
        "chmod 666 ${vm_pool}/${name}-${subname}.qcow2"
    );
    assert_script_run(
        'curl '
          . data_url(
            "cpu_bugs/vm_install_script/sle-15/create_vm_with_exist_disk.sh")
          . ' -o create_vm_with_exist_disk.sh',
        60
    );
    assert_script_run('chmod 755 create_vm_with_exist_disk.sh');
    assert_script_run(
        "./create_vm_with_exist_disk.sh ${name}  ${subname}  ${vm_pool} ${cpu_1}"
    );

}

sub run {
    systemctl("stop apparmor");
    script_run("aa-teardown");
    zypper_call("in libvirt-client");
    zypper_call("in qemu-kvm");
    zypper_call("in -t pattern kvm_server kvm_tools");
    assert_script_run("mkdir -pv $vm_shares");
    assert_script_run("mkdir -pv $vm_pool");
    if (get_var("MIGRATION_HOST")) {
        mutex_create "flag_lock";
        my $children = get_children();
        my $child_id = (keys %$children)[0];
        assert_script_run("cp /etc/exports{,.bak}");
        assert_script_run(
            "sed -i \"/^" . "\\" . ${vm_shares} . "/d\" /etc/exports");

        #setup NFS and release a lock to notice client side
        zypper_call("in nfs-kernel-server");
        assert_script_run(
            "echo \"$vm_shares *(rw,sync,no_root_squash)\" >>/etc/exports");
        systemctl("restart nfs-server.service");
        mutex_create 'nfs_server_ready';

        #waiting for client to finish initial operation
        mutex_wait('dest_host_ready', $child_id);

        #Do migrate
        assert_script_run("mount $source_host:$vm_shares $vm_pool");
        #Initial task
        jobs_done();

    }
    elsif (get_var("MIGRATION_DEST")) {

        if (is_sle('>=15-sp2')) {
            systemctl("start libvirtd-tcp.socket");
        } else {
            #access this machine without password

            assert_script_run("cp /etc/libvirt/libvirtd.conf{,.bak}");
            assert_script_run(
                "sed -i 's/#listen_tcp = 1/listen_tcp = 1/g' /etc/libvirt/libvirtd.conf"
            );
            assert_script_run(
                "sed -i 's/#auth_tcp = .*/auth_tcp = \"none\"/g' /etc/libvirt/libvirtd.conf"
            );
            systemctl("restart libvirtd");
            systemctl("status libvirtd");
        }

        #wait server side is ready
        mutex_lock 'nfs_server_ready';

        zypper_call("in nfs-client");
        assert_script_run("mkdir -pv $vm_pool");
        assert_script_run("mount $source_host:$vm_shares $vm_pool");

        mutex_create 'dest_host_ready';

    }

    for my $c (split /,/, $cpu) {
        ${cpu_1} = $c;
        $subname =
          script_output("echo ${cpu_1} | sha1sum | awk \'{print \$1}\'");
        while (1) {
            mutex_lock "flag_lock";
            if (check_idle_status() == 0) {
                if (get_var("MIGRATION_HOST")) {
                    remove_old_vm();
                    create_new_vm();
                    assert_script_run(
                        "virsh start $name-$subname",
                        fail_message =>
                          "You need run install testcase to setup a KVM guest for migration."
                    );
                    assert_script_run(
                        "virsh migrate --live $name-$subname --verbose qemu+tcp://$dest_host/system"
                    );

                    assert_script_run(
                        "virsh list | grep -v \"$name-$subname\"");
                    assert_script_run(
                        "virsh list --all | grep \"${name}-$subname.*shut off\""
                    );
                    goto_work();
                    mutex_unlock "flag_lock";
                    last;

                }
                else {
                    mutex_unlock "flag_lock";
                    assert_script_run("echo DEST side wait HOST side.");
                    next;
                }
            }
            if (check_working_status() == 0) {
                if (get_var("MIGRATION_HOST")) {
                    mutex_unlock "flag_lock";
                    next;
                }
                else {
                    #waiting migrate until finish
                    assert_script_run("virsh list | grep $name-$subname");
                    assert_script_run("virsh destroy $name-$subname");
                    jobs_done();
                    mutex_unlock "flag_lock";
                    last;
                }
            }
            mutex_unlock "flag_lock";
        }
    }

    if (get_var("MIGRATION_DEST")) {
        #cleanup
        assert_script_run("cp /etc/libvirt/libvirtd.conf{.bak,}");
    }
    if (get_var("MIGRATION_HOST")) {
        assert_script_run("cp /etc/exports{.bak,}");
    }
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    if (get_var("MIGRATION_HOST")) {
        assert_script_run(
            "sed -i \"/^" . "\\" . ${vm_pool} . "/d\" /etc/exports");
        assert_script_run("cp /etc/exports{.bak,}");
    }
    elsif (get_var("MIGRATION_DEST")) {
        assert_script_run("cp /etc/libvirt/libvirtd.conf{.bak,}");
    }
    assert_script_run('virsh list > /tmp/virsh_list.log');
    upload_logs("/tmp/virsh_list.log");
    upload_logs("/var/log/libvirt/qemu/${name}-${subname}.log");
    upload_logs("/var/log/libvirt/qemu/${name}-${subname}.log");
    $self->SUPER::post_fail_hook;
}

1;
