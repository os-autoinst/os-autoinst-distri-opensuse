# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This module copies all files from USB to µSD on Raspberry Pi (required to chain boot from µSD to USB).
# It is currently used on:
#   * RPi2 v1.1: as it cannot boot directly from USB at all
#   * RPi2 v1.2 / RPi3: will use bootcode.bin only once https://github.com/raspberrypi/firmware/issues/1322 will be fixed
# It does not support:
#   * RPi4 : as it cannot boot from USB (USB is not supported neither in firmware, nor in u-boot)
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use Utils::Architectures 'is_aarch64';

sub run {
    my ($self) = @_;

    select_console('root-console');

    # Mount SD card
    assert_script_run('mount /dev/mmcblk0p1 /mnt');

    # Clean target
    assert_script_run('rm -rf /mnt/*');
    # Copy required files (firmware, firmware-config, firmware-dt, firmware-dt overlays, u-boot bin)
    assert_script_run('rsync --recursive /boot/efi/{bootcode.bin,*.elf,*.dat,*.dtb,config.txt,u-boot.bin,overlays} /mnt/');
    # u-boot config is only available in u-boot-rpiarm64 package for rpi3/4 to boot in 64-bit mode
    assert_script_run('cp /boot/efi/ubootconfig.txt /mnt/') if is_aarch64;
    # Show files
    assert_script_run('ls /mnt/');

    # Enable debug output on bootcode.bin firmware
    assert_script_run('sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" /mnt/bootcode.bin');

    # Unmount SD card
    assert_script_run('umount /mnt');
}

1;
