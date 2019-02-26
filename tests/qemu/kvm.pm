# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run QEMU using KVM
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;


sub run {
    select_console 'root-console';

    if (check_var('ARCH', 'x86_64')) {
        type_string "qemu-system-x86_64 -nographic -enable-kvm\n";
        assert_screen 'qemu-no-bootable-device', 60;
    }
    elsif (check_var('ARCH', 'ppc64le')) {
        type_string "qemu-system-ppc64 -nographic -enable-kvm\n";
        assert_screen ['qemu-open-firmware-ready', 'qemu-does-not-support-1tib-segments'], 60;
        if (match_has_tag 'qemu-does-not-support-1tib-segments') {
            record_soft_failure 'bsc#1124589 - qemu on ppx64le fails when called with kvm on POWER9';
            return;
        }
    }
    elsif (check_var('ARCH', 's390x')) {
        type_string "qemu-system-s390x -nographic -enable-kvm -kernel /tmp/kernel -initrd /boot/initrd\n";
        assert_screen 'qemu-reached-target-basic-system', 60;
    }
    elsif (check_var('ARCH', 'aarch64')) {
        type_string "qemu-system-aarch64 -M virt,usb=off,gic-version=host -cpu host -enable-kvm -nographic -pflash flash0.img -pflash flash1.img\n";
        assert_screen 'qemu-uefi-shell', 600;
    }

    # close qemu
    send_key 'ctrl-a';
    send_key 'x';
    assert_script_run '$(exit $?)';
}

1;
