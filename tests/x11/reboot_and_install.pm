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
    # reboot from previously booted hdd to do pre check or change e.g. before upgrade
    reboot_gnome;

    # on s390 zKVM we handle the boot of the patched system differently
    set_var('PATCHED_SYSTEM', 1) if get_var('PATCH');
    return if get_var('S390_ZKVM');

    # give some time to shutdown+reboot from gnome. Also, because mainly we
    # are coming from old systems here it is unlikely the reboot time
    # increases
    return if select_bootmenu_option(300) == 3;
    bootmenu_default_params;
    specific_bootmenu_params;
    registration_bootloader_params;
    # boot
    my $key = check_var('ARCH', 'ppc64le') ? 'ctrl-x' : 'ret';
    send_key $key;
}

sub post_fail_hook {
    my $self = shift;
    $self->export_logs;
}

sub test_flags() {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
