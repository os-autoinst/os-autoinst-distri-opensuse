# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run QEMU as emulator
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;


sub run {
    select_console 'root-console';

    zypper_call 'in qemu';

    if (check_var('ARCH', 'x86_64')) {
        zypper_call 'in qemu-x86';
        type_string "qemu-system-x86_64 -nographic\n";
        assert_screen 'qemu-no-bootable-device', 60;
    }
    elsif (check_var('ARCH', 'ppc64le')) {
        zypper_call 'in qemu-ppc';
        type_string "qemu-system-ppc64 -nographic\n";
        assert_screen ['qemu-open-firmware-ready', 'qemu-ppc64-no-trans-mem'], 60;
        if (match_has_tag 'qemu-ppc64-no-trans-mem') {
            # this should only happen on SLE12SP5
            record_info 'workaround', 'bsc#1118450 - qemu-system-ppc64: KVM implementation does not support Transactional Memory';
            type_string "qemu-system-ppc64 -nographic -M usb=off,cap-htm=off\n";
            assert_screen 'qemu-open-firmware-ready', 60;
        }
    }
    elsif (check_var('ARCH', 's390x')) {
        zypper_call 'in qemu-s390';
        # use kernel from host system for booting
        assert_script_run 'zcat $(ls /boot/vmlinux-* | sort | tail -1) > /tmp/kernel';
        type_string "qemu-system-s390x -nographic -kernel /tmp/kernel -initrd /boot/initrd\n";
        assert_screen ['qemu-reached-target-basic-system', 'qemu-s390x-exec-0x7f4-not-impl'], 60;
        if (match_has_tag 'qemu-s390x-exec-0x7f4-not-impl') {
            record_soft_failure 'bsc#1124595 - qemu on s390x fails when called WITHOUT kvm: EXECUTE on instruction prefix 0x7f4 not implemented';
            return;
        }
    }
    elsif (check_var('ARCH', 'aarch64')) {
        zypper_call 'in qemu-arm';
        # create pflash volumes for UEFI as described on https://wiki.ubuntu.com/ARM64/QEMU
        assert_script_run 'dd if=/dev/zero of=flash0.img bs=1M count=64';
        assert_script_run 'dd if=/usr/share/qemu/qemu-uefi-aarch64.bin of=flash0.img conv=notrunc';
        assert_script_run 'dd if=/dev/zero of=flash1.img bs=1M count=64';
        type_string "qemu-system-aarch64 -M virt,usb=off -cpu cortex-a57 -nographic -pflash flash0.img -pflash flash1.img\n";
        assert_screen 'qemu-uefi-shell', 600;
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
