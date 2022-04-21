# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run QEMU using KVM
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use Utils::Architectures;
use utils;


sub run {
    select_console 'root-console';

    if (is_x86_64) {
        enter_cmd "qemu-system-x86_64 -nographic -enable-kvm";
        assert_screen 'qemu-no-bootable-device', 60;
    }
    elsif (is_ppc64le) {
        enter_cmd "qemu-system-ppc64 -nographic -enable-kvm";
        assert_screen ['qemu-open-firmware-ready', 'qemu-does-not-support-1tib-segments', 'qemu-ppc64-no-trans-mem'], 60;
        if (match_has_tag 'qemu-does-not-support-1tib-segments') {
            record_soft_failure 'bsc#1124589 - qemu on ppx64le fails when called with kvm on POWER9';
            return;
        }
        elsif (match_has_tag 'qemu-ppc64-no-trans-mem') {
            # this should only happen on SLE12SP5
            record_info 'workaround', 'bsc#1118450 - qemu-system-ppc64: KVM implementation does not support Transactional Memory';
            enter_cmd "qemu-system-ppc64 -nographic -enable-kvm -M usb=off,cap-htm=off";
            assert_screen 'qemu-open-firmware-ready', 60;
        }
    }
    elsif (is_s390x) {
        # Native kvm requires SIE support (start-interpretive execution)
        die "SIE support on s390x cpu required for native kvm" if (script_run('grep sie /proc/cpuinfo') != 0);
        enter_cmd "qemu-system-s390x -nographic -enable-kvm -kernel /boot/image -initrd /boot/initrd";
        assert_screen 'qemu-reached-target-basic-system', 60;
    }
    elsif (is_aarch64) {
        enter_cmd "qemu-system-aarch64 -M virt,usb=off,gic-version=host -cpu host -enable-kvm -nographic -pflash flash0.img -pflash flash1.img";
        assert_screen 'qemu-uefi-shell', 600;
    }

    # close qemu
    send_key 'ctrl-a';
    send_key 'x';
    assert_script_run '$(exit $?)';
}

1;
