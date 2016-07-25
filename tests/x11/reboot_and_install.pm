# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;

use testapi;
use utils qw/reboot_gnome/;
use bootloader_setup qw/select_bootmenu_option bootmenu_default_params/;

sub run() {
    reboot_gnome;    # reboot from previously booted hdd to do pre check or change e.g. before upgrade
    select_bootmenu_option;
    bootmenu_default_params;
    # boot
    send_key "ret";
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
