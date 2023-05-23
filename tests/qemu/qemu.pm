# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run QEMU as emulator
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use Utils::Backends;
use utils;
use transactional qw(trup_call check_reboot_changes);
use Utils::Architectures;
use version_utils qw(is_sle_micro is_leap_micro is_transactional);

# 'patterns-microos-kvm_host' is required for SUMA client use case
sub is_qemu_preinstalled {
    if (is_sle_micro || is_leap_micro) {
        assert_script_run('rpm -q patterns-microos-kvm_host');
        return 1;
    }
    return 0;
}

sub install_qemu {
    my $qpkg = shift;
    if (is_transactional) {
        trup_call("pkg install $qpkg");
        check_reboot_changes;
    } else {
        zypper_call("in $qpkg");
    }
}

sub run {
    select_console 'root-console';

    if (is_x86_64) {
        is_qemu_preinstalled or install_qemu('qemu-x86');
        enter_cmd "qemu-system-x86_64 -nographic";
        assert_screen 'qemu-no-bootable-device', 60;
    }
    elsif (is_ppc64le) {
        is_qemu_preinstalled or install_qemu('qemu-ppc');
        enter_cmd "qemu-system-ppc64 -nographic";
        assert_screen ['qemu-open-firmware-ready', 'qemu-ppc64-no-trans-mem'], 60;
        if (match_has_tag 'qemu-ppc64-no-trans-mem') {
            # this should only happen on SLE12SP5
            record_info 'workaround', 'bsc#1118450 - qemu-system-ppc64: KVM implementation does not support Transactional Memory';
            enter_cmd "qemu-system-ppc64 -nographic -M usb=off,cap-htm=off";
            assert_screen 'qemu-open-firmware-ready', 60;
        }
    }
    elsif (is_s390x) {
        is_qemu_preinstalled or install_qemu('qemu-s390x');
        # use kernel from host system for booting
        enter_cmd "qemu-system-s390x -nographic -kernel /boot/image -initrd /boot/initrd";
        assert_screen ['qemu-reached-target-basic-system', 'qemu-s390x-exec-0x7f4-not-impl', 'qemu-linux-req-more-recent-proc-hw'], 180;
        if (match_has_tag 'qemu-s390x-exec-0x7f4-not-impl') {
            record_soft_failure 'bsc#1124595 - qemu on s390x fails when called WITHOUT kvm: EXECUTE on instruction prefix 0x7f4 not implemented';
            return;
        }
        elsif (match_has_tag 'qemu-linux-req-more-recent-proc-hw') {
            record_soft_failure 'bsc#1127722 - qemu on s390x fails when called WITHOUT kvm: Linux Kernel requires newer processor';
            return;
        }
    }
    elsif (is_aarch64) {
        is_qemu_preinstalled or install_qemu('qemu-arm qemu-uefi-aarch64 qemu-ipxe');
        # create pflash volumes for UEFI as described on https://wiki.ubuntu.com/ARM64/QEMU
        assert_script_run 'dd if=/dev/zero of=flash0.img bs=1M count=64';
        assert_script_run 'dd if=/usr/share/qemu/qemu-uefi-aarch64.bin of=flash0.img conv=notrunc';
        assert_script_run 'dd if=/dev/zero of=flash1.img bs=1M count=64';
        enter_cmd "qemu-system-aarch64 -M virt,usb=off -cpu cortex-a57 -nographic -pflash flash0.img -pflash flash1.img";
        assert_screen 'qemu-uefi-shell', 600;
    }
    else {
        die sprintf("Test case is missing support for %s architecture", get_var('ARCH'));
    }

    # close qemu
    send_key 'ctrl-a';
    send_key 'x';
    assert_script_run '$(exit $?)';
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
