# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bootloader to setup boot process with arguments/options
# Maintainer: Jozef Pupava <jpupava@suse.com>

package bootloader;

use base "installbasetest";
use strict;
use warnings;

use testapi;
use lockapi 'mutex_wait';
use bootloader_setup;
use bootloader_spvm;
use registration;
use version_utils qw(:VERSION :SCENARIO);
use utils;
use Utils::Backends 'is_spvm';

# hint: press shift-f10 trice for highest debug level
sub run {
    return boot_spvm if is_spvm;
    return           if pre_bootmenu_setup == 3;
    return           if select_bootmenu_option == 3;
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
    push @params, specific_bootmenu_params;
    specific_caasp_params;
    push @params, registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);
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
