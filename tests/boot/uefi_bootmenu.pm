# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select UEFI boot device in BIOS
#    OVMF doesn't honor the -boot XX setting of qemu so we have to manually enter the boot manager in the BIOS
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup;

sub run {
    my ($self) = @_;
    # because of broken firmware, bootindex doesn't work on aarch64 bsc#1022064
    # selecting a workaround is handled in boot/boot_to_desktop
    return if (get_var('MACHINE') =~ /aarch64/ && get_var('BOOT_HDD_IMAGE'));
    tianocore_select_bootloader;
    if (check_var('BOOTFROM', 'd')) {
        send_key_until_needlematch('tianocore-bootmanager-dvd', 'down', 5, 1);
    }
    elsif (check_var('BOOTFROM', 'c')) {
        send_key_until_needlematch("ovmf-boot-HDD", 'down', 5, 1);
    }
    else {
        die "BOOTFROM value not supported";
    }
    send_key 'ret';
}

sub test_flags {
    return {fatal => 1};
}

1;
