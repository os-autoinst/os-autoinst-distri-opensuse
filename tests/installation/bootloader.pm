# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;

use testapi;
use bootloader_setup;
use registration;

# hint: press shift-f10 trice for highest debug level
sub run() {
    return if pre_bootmenu_setup == 3;
    return if select_bootmenu_option == 3;
    bootmenu_default_params;
    bootmenu_network_source;
    specific_bootmenu_params;
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);
    select_bootmenu_language;
    select_bootmenu_video_mode;
    # boot
    send_key "ret";
}

1;
# vim: set sw=4 et:
