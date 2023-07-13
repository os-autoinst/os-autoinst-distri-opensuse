# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure the system can reboot from gnome
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use warnings;

use testapi;
use Utils::Architectures;
use utils 'workaround_type_encrypted_passphrase';
use power_action_utils 'power_action';
use version_utils 'is_sle12_hdd_in_upgrade';

use bootloader_setup;
use registration;

sub run {
    # reboot from previously booted hdd to do pre check or change e.g. before upgrade
    power_action('reboot');
    workaround_type_encrypted_passphrase;

    # If the target has a different version, make sure the matching needles are used
    # for the bootmenu below already.
    if (get_var('UPGRADE_TARGET_VERSION')) {
        # Switch to upgrade target version and reload needles
        set_var('VERSION', get_var('UPGRADE_TARGET_VERSION'), reload_needles => 1);
    }

    # on s390 zKVM we handle the boot of the patched system differently
    set_var('PATCHED_SYSTEM', 1) if get_var('PATCH');
    return if get_var('S390_ZKVM');

    # give some time to shutdown+reboot from gnome. Also, because mainly we
    # are coming from old systems here it is unlikely the reboot time
    # increases
    return if select_bootmenu_option(300) == 3;
    # set uefi bootmenu parameters properly for aarch64, such like gfxpayload and so on
    if (is_aarch64) {
        uefi_bootmenu_params;
    }
    bootmenu_default_params;
    specific_bootmenu_params;
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);

    # Stop the bootloader timeout in "zdup" upgrade where we expect the
    # bootloader entry to be still shown later on and just in case it is
    # already shown here. In other cases select the default boot entry.
    if (get_var('ZDUP')) {
        stop_grub_timeout;
    }
    else {
        # boot
        my $key = get_var('OFW') || is_aarch64 ? 'ctrl-x' : 'ret';
        send_key $key;
    }

    # All actions have been done e.g. fully/minimal patch on booted hdd before this step
    # After this, the hdd would be upgraded to the target version in case of Upgrade scenario
    if (is_sle12_hdd_in_upgrade) {
        set_var('HDDVERSION', get_var('VERSION'));
    }
}

sub post_fail_hook {
    my $self = shift;
}

sub test_flags {
    return {fatal => 1};
}

1;

