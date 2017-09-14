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

use testapi;
use lockapi;
use bootloader_setup;
use registration;

# hint: press shift-f10 trice for highest debug level
sub run {
    return if pre_bootmenu_setup == 3;
    return if select_bootmenu_option == 3;
    bootmenu_default_params;
    bootmenu_network_source;
    specific_bootmenu_params;
    specific_caasp_params;
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);
    # if a support_server is used, we need to wait for him to finish its initialization
    # and we need to do it *before* starting the OS, as a DHCP request can happen too early
    if (check_var('USE_SUPPORT_SERVER', 1)) {
        diag "Waiting for support server to complete setup...";

        # we use mutex to do this
        mutex_lock('support_server_ready');
        mutex_unlock('support_server_ready');
    }
    # on ppc64le boot have to be confirmed with ctrl-x or F10
    # and it doesn't have nice graphical menu with video and language options
    if (!check_var('ARCH', 'ppc64le')) {
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
# vim: set sw=4 et:
