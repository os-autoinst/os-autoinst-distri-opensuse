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
use warnings;
use testapi;
use bootloader_setup qw(change_grub_config grep_grub_settings grub_mkconfig set_framebuffer_resolution set_extrabootparams_grub_conf);

sub run {
    change_grub_config('=.*', '=1024x768', 'GRUB_GFXMODE=');
    change_grub_config('^#',  '',          'GRUB_GFXMODE');
    change_grub_config('=.*', '=-1',       'GRUB_TIMEOUT') unless check_var('VIRSH_VMM_TYPE', 'linux');
    grep_grub_settings('^GRUB_GFXMODE=1024x768$');
    set_framebuffer_resolution;
    set_extrabootparams_grub_conf;
    grub_mkconfig;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
