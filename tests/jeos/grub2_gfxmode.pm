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

# Summary: Set GRUB_GFXMODE to 1024x768
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use bootloader_setup qw(set_framebuffer_resolution set_extrabootparams_grub_conf);

sub run {
    assert_script_run("sed -ie '/GRUB_GFXMODE=/s/=.*/=1024x768/' /etc/default/grub");
    assert_script_run("sed -ie '/GRUB_GFXMODE/s/^#//' /etc/default/grub");
    assert_script_run('grep ^GRUB_GFXMODE=1024x768$ /etc/default/grub');
    set_framebuffer_resolution;
    set_extrabootparams_grub_conf;
    assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
