# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SUSE or openSUSE WSL images from the MS Store directly
# Maintainer: qa-perf  <qa-perf@suse.de>

use base 'y2_installbase';

use strict;
use warnings;
use testapi;
use utils;

my $NETCONFIG_IFCFGBR0 = "BOOTPROTO='dhcp4'\nSTARTMODE='auto'\nBRIDGE='yes'\nBRIDGE_PORTS='em1'\nBRIDGE_STP='off'\nBRIDGE_FORWARDDELAY='15'\nZONE=public";
my $NETCONFIG_IFCFGEM1 = "BOOTPROTO='none'\nSTARTMODE='auto'";

sub run {
    my $output = '';
    my $alp_flavor = lc(get_required_var('FLAVOR'));
    my $alp_build = get_required_var('BUILD');
    $alp_build =~ s/\.//;
    my $abuild_qcow2 = "/abuild/btrfs/abuild_alp_$alp_flavor-$alp_build.qcow2";
    my $alp_image = "ALP-" . (split('-', get_required_var("FLAVOR")))[0] . "." . get_required_var("ARCH") . "-" . get_required_var("VERSION") . "-" . (split('-', get_required_var("FLAVOR")))[1] . "-qcow-Build" . get_required_var("BUILD") . ".qcow2";
    my $alp_serial_log = "/tmp/alp_serial_log";
    my $VCPU = 6;
    my $MEM = 5120;

    # Step 1: prepare KVM
    record_info('KVM setup', 'Install and configure KVM and libvirtd');
    $output = script_output('zypper se -t pattern kvm');
    die("Pattern 'kvm' not found!") unless (($output =~ m/kvm_server/)
        && ($output =~ m/kvm_tools/));
    zypper_call('in -t pattern kvm_*');
    assert_script_run('systemctl enable --now libvirtd');


    # Step 2: prepare network
    record_info('Setup network', 'Setup network bridge interface');
    assert_script_run(qq(echo -e "$NETCONFIG_IFCFGBR0" > /etc/sysconfig/network/ifcfg-br0));
    assert_script_run(qq(echo -e "$NETCONFIG_IFCFGEM1" > /etc/sysconfig/network/ifcfg-em1));
    assert_script_run('systemctl restart network', timeout => 60);


    # Step 3: setup abuild
    record_info('Setup abuild', 'abuild setup for performance IO case');
    if (index(script_output("df -h | grep sdb1", proceed_on_failure => 1), m/sdb1/) == -1) {
        assert_script_run("fdisk /dev/sdb");
        assert_script_run("mkfs.btrfs /dev/sdb1 -f -L ABUILD");
        assert_script_run("mkdir -p /abuild/btrfs");
        assert_script_run("mount -L ABUILD /abuild/btrfs/");
    }
    # Check if there's an ALP_m domain created and delete it if so
    $output = script_output("virsh list --all | grep ALP_m");
    if ($output =~ m/ALP/) {
        assert_script_run("virsh destroy ALP_m") unless ($output =~ m/shut off/);
        assert_script_run("virsh undefine ALP_m");
    }
    assert_script_run("qemu-img create -f qcow2 $abuild_qcow2 200G");
    assert_script_run("chmod 777 -R /abuild/");


    # Step 4: prepare files for the VM
    assert_script_run("mkdir -p /tmp/ignition && wget -O /tmp/ignition/config.ign " . data_url("alp_performance/VM_config.ign"));
    # Download ALP-%FLAVOR1%.%ARCH%-%VERSION%-%FLAVOR2%-qcow-Build%BUILD%.qcow2
    # from https://openqa.suse.de/assets/hdd/
    assert_script_run("wget -O /tmp/$alp_image --no-check-certificate https://openqa.suse.de/assets/hdd/$alp_image", timeout => 300);


    # Step 5: virt-install setup
    background_script_run("virt-install " .
          "--connect qemu:///system " .
          "--import " .
          "--name ALP_m " .
          "--boot hd " .
          "--osinfo opensusetumbleweed " .
          "--virt-type kvm --hvm " .
          "--machine q35 " .
          "--cpu host-passthrough " .
          "--console=\"log.file=$alp_serial_log\" " .
          "--console pty,target_type=virtio " .
          "--network bridge=br0,model=virtio " .
          "--rng /dev/urandom " .
          "--tpm backend.type=emulator,backend.version=2.0,model=tpm-tis " .
          "--vcpu $VCPU --memory $MEM " .
          "--sysinfo type=fwcfg,entry0.name=\"opt/com.coreos/config\",entry0.file=/tmp/ignition/config.ign " .
          "--disk size=24,backing_store=/tmp/$alp_image,backing_format=qcow2,bus=virtio,cache=none " .
          "--qemu-commandline=\"-drive file=$abuild_qcow2,format=qcow2,l2-cache-size=8388608,if=none,cache=none\" " .
          "--graphics vnc,listen=0.0.0.0 ");
}

1;
