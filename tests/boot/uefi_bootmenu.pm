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
use testapi;
use utils;
use bootloader_setup;

sub check_ret_accepted {
    my $tag = shift;
    wait_screen_change(
        sub {
            send_key 'ret';
        },
        5
    );
    return !check_screen($tag, timeout => 0);
}

sub run() {
    tianocore_select_bootloader;
    my $matchtag;
    if (check_var('BOOTFROM', 'd')) {
        send_key_until_needlematch('tianocore-bootmanager-dvd', 'down', 5, 1);
        $matchtag = 'tianocore-bootmanager-dvd';
    }
    elsif (check_var('BOOTFROM', 'c')) {
        send_key_until_needlematch("ovmf-boot-HDD", 'down', 5, 1);
        $matchtag = 'ovmf-boot-HDD';
    }
    else {
        die "BOOTFROM value not supported";
    }
    my $counter = 60;
    while ($counter--) {
        last if check_ret_accepted($matchtag);
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
