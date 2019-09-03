# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# JeOS with kernel-default-base doesn't use kms, so the default mode
# 1024x768 of the cirrus kms driver doesn't help us. We need to
# manually configure grub to tell the kernel what mode to use.

# Summary:  Reach GRUB2 menu
#			Cancel time out counter
#			Set gfxpayload to 1024x768
#			Boot deployed image
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use bootloader_setup 'uefi_bootmenu_params';

sub run {
    my $self = shift;

    # JeOS images GRUB2 timeout is set to 10s
    my $counter = 0;
    while ((!check_screen('grub2', 1)) && ($counter < 10)) {
        wait_screen_change(sub {
                send_key 'home';
        }, 0.5);
        $counter++;
    }
    $self->wait_grub(in_grub => 1, bootloader_time => 10);
    uefi_bootmenu_params;
    send_key "f10";
}

sub test_flags {
    return {fatal => 1};
}

1;
