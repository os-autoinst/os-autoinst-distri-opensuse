# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select resolution in bootloader and halt
# - This is a simple test for saving a modified ovmf-x86_64-ms-vars.bin
#   as a public asset
# - Example settings:
#   UEFI_PFLASH_CODE=/usr/share/qemu/ovmf-x86_64-ms-code.bin UEFI_PFLASH_VARS=/usr/share/qemu/ovmf-x86_64-ms-vars.bin PUBLISH_PFLASH_VARS=ovmf-x86_64-ms-vars-800x600.qcow2
# Maintainer: Tina <tina.mueller@suse.com>

use Mojo::Base 'bootbasetest', -signatures;
use testapi;
use Utils::Architectures;
use bootloader_setup;

sub run ($self) {
    tianocore_set_svga_resolution();
    my $bootloader_timeout = is_aarch64 ? 90 : 15;
    assert_screen "bootloader-grub2", $bootloader_timeout;
    send_key 'c';
    assert_screen "bootloader-grub2-cmd";
    enter_cmd("halt");
}

1;
