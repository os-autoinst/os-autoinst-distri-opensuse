# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bootloader to setup boot process with arguments/options
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "installbasetest";
use strict;
use warnings;

use testapi;
use lockapi 'mutex_wait';
use bootloader_setup;
use registration;
use utils;

# hint: press shift-f10 trice for highest debug level
sub run {
    return if pre_bootmenu_setup == 3;
    return if select_bootmenu_option == 3;
    bootmenu_default_params;
    bootmenu_network_source;
    specific_bootmenu_params;
    specific_caasp_params;
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);
    mutex_wait 'support_server_ready' if get_var('USE_SUPPORT_SERVER');
    # on ppc64le boot have to be confirmed with ctrl-x or F10
    # and it doesn't have nice graphical menu with video and language options
    if (!get_var('OFW')) {
        select_bootmenu_language;
        select_bootmenu_video_mode;
        # boot
        send_key 'ret';
    }
    else {
        # boot
        send_key 'ctrl-x';
    }
}

1;
