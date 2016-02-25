# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# JeOS with kernel-default-base doesn't use kms, so the default mode
# 1024x768 of the cirrus kms driver doesn't help us. We need to
# manually configure grub to tell the kernel what mode to use.

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    if (check_var('UEFI', '1')) {
        assert_script_run("sed -ie '/GRUB_GFXMODE=/s/=.*/=1024x768/' /etc/default/grub && grub2-mkconfig -o /boot/grub2/grub.cfg");
        # workaround kiwi quirk bnc#968270, bnc#968264
        assert_script_run("rm -rf /boot/efi/EFI; sed -ie 's/which/echo/' /usr/sbin/shim-install && shim-install");
    }
    else {
        assert_script_run("sed -ie '/GFXPAYLOAD_LINUX=/s/=.*/=1024x768/' /etc/default/grub && grub2-mkconfig -o /boot/grub2/grub.cfg");
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
