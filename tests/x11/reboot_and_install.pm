# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
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
use utils qw(power_action workaround_type_encrypted_passphrase);
use bootloader_setup;
use registration;

sub run() {
    # reboot from previously booted hdd to do pre check or change e.g. before upgrade
    power_action('reboot');
    workaround_type_encrypted_passphrase;

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

    # Stop the bootloader timeout in "zdup" upgrade where we expect the
    # bootloader entry to be still shown later on and just in case it is
    # already shown here. In other cases select the default boot entry.
    if (get_var('ZDUP')) {
        stop_grub_timeout;
    }
    else {
        # boot
        my $key = check_var('ARCH', 'ppc64le') ? 'ctrl-x' : 'ret';
        send_key $key;
    }
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
