# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Bootloader to setup boot process with arguments/options
# - Check if bootloader is isolinux or grub and set different commands for each
# - Create a array containing all the actions for bootloader phase
# bootmenu_default_params,bootmenu_network_source, specific_bootmenu_params
# registration_bootloader_params
# - If bootloader is grub, try to set graphics mode to 1024x768
#   - If is NETBOOT, type "install=" in bootloader command line
#   - If product is Jeos and VIDEOMODE is "text", type videomode=1 on bootloader
#   command line
# - Wait for mutex wait if USE_SUPPORT_SERVER is defined
# - If OFW is not defined, set bootloader language and set bootloader video
# mode, otherwise sent "ctrl-x"
# - Send ret or ctrl-x to boot system
# - Compare boot parameters with parameters obtained by serial, unless it is
# live image
# Maintainer: Jozef Pupava <jpupava@suse.com>

package bootloader;

use base "installbasetest";
use strict;
use warnings;

use testapi;
use lockapi 'mutex_wait';
use bootloader_setup;
use bootloader_pvm;
use registration;
use version_utils qw(:VERSION :SCENARIO);
use utils;
use Utils::Backends 'is_pvm';

# hint: press shift-f10 trice for highest debug level
sub run {
    return boot_pvm if is_pvm;
    return if get_var('BOOT_HDD_IMAGE');
    return if select_bootmenu_option == 3;
    # the default loader is isolinux on openSUSE/SLE products with product-builder
    my $boot_cmd = 'ret';
    # Tumbleweed livecd has been switched to grub with kiwi 9.17.41 except 32bit
    # when LIVECD_LOADER has set grub2 then change the boot command for grub2
    if (is_livecd && check_var('LIVECD_LOADER', 'grub2')) {
        $boot_cmd = 'ctrl-x';
        uefi_bootmenu_params;
    }
    my @params;
    push @params, bootmenu_default_params;
    push @params, bootmenu_network_source;
    push @params, bootmenu_remote_target;
    push @params, specific_bootmenu_params;
    push @params, registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED) unless get_var('SLP_RMT_INSTALL') || is_opensuse;
    mutex_wait 'support_server_ready' if get_var('USE_SUPPORT_SERVER');
    # on ppc64le boot have to be confirmed with ctrl-x or F10
    # and it doesn't have nice graphical menu with video and language options
    if (!get_var('OFW')) {
        select_bootmenu_language;
        select_bootmenu_video_mode;
    } else {
        $boot_cmd = 'ctrl-x';
    }
    # boot
    send_key $boot_cmd;
    # On the live images boot parameters are not printed on the serial,
    # skip the check there
    compare_bootparams(\@params, [parse_bootparams_in_serial]) if !is_livecd;
}

1;
