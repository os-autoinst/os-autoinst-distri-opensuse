# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure the system can reboot from gnome
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;

use testapi;
use utils 'reboot_gnome';
use bootloader_setup;
use registration;

sub run() {
    reboot_gnome;    # reboot from previously booted hdd to do pre check or change e.g. before upgrade
    return if select_bootmenu_option == 3;
    bootmenu_default_params;
    specific_bootmenu_params;
    registration_bootloader_params;
    # boot
    send_key "ret";
}

sub post_fail_hook {
    my $self = shift;
    $self->export_logs;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
