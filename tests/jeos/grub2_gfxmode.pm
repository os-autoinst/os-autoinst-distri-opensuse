# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# JeOS with kernel-default-base doesn't use kms, so the default mode
# 1024x768 of the cirrus kms driver doesn't help us. We need to
# manually configure grub to tell the kernel what mode to use.

# Summary: set gfxplayload for grub
#    JeOS doesn't inherit the gfx settings from the first boot so we need
#    to adjust the grub config manually to survive reboots.
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils 'is_jeos';

sub run {
    my $video;
    if (check_var('UEFI', '1')) {
        assert_script_run("sed -ie '/GRUB_GFXMODE=/s/=.*/=1024x768/' /etc/default/grub");
        # workaround kiwi quirk bsc#968270, bsc#968264
        assert_script_run("rm -rf /boot/efi/EFI; sed -ie 's/which/echo/' /usr/sbin/shim-install && shim-install");
    }
    else {
        assert_script_run("sed -ie '/GFXPAYLOAD_LINUX=/s/=.*/=1024x768/' /etc/default/grub");
    }

    # For Hyper-V and Xen PV we need to add special framebuffer provisions
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $video = "video=hyperv_fb:1024x768";
    }
    elsif (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) {
        $video = 'xen-fbfront.video=32,1024,768 xen-kbdfront.ptr_size=1024,768 ';
    }

    if ($video) {
        # On JeOS we have GRUB_CMDLINE_LINUX, on CaaSP we have GRUB_CMDLINE_LINUX_DEFAULT.
        my $grub_cmdline_label = is_jeos() ? 'GRUB_CMDLINE_LINUX' : 'GRUB_CMDLINE_LINUX_DEFAULT';
        assert_script_run("sed -ie '/${grub_cmdline_label}=/s/\"\$/ $video \"/' /etc/default/grub");
    }
    assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
