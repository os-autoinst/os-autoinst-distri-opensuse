# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Reboot machine to perform upgrade
#       Just trigger reboot action, afterwards tests will be
#       incepted by later test modules, such as tests in
#       load_boot_tests or wait_boot in setup_zdup.pm
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use Utils::Backends 'is_pvm';
use power_action_utils 'power_action';
use bootloader_setup 'stop_grub_timeout';
use version_utils;
use x11utils 'turn_off_gnome_show_banner';

sub run {
    my ($self) = @_;
    # We need to close gnome notification banner before migration.
    if (check_var('DESKTOP', 'gnome')) {
        select_console 'user-console';
        turn_off_gnome_show_banner;
    }
    select_console 'root-console';

    # Mark the hdd has been patched
    set_var('PATCHED_SYSTEM', 1) if get_var('PATCH');

    # Reboot from Installer media for upgrade
    # Aarch64 need BOOT_HDD_IMAGE=1 to keep the correct flow to boot from disk for x11/reboot_gnome.
    # but in Aarch64 zdup migration we need to set it to 0, this will make it boot from hard disk.
    if (get_var('UPGRADE') || get_var('AUTOUPGRADE')) {
        set_var('BOOT_HDD_IMAGE', 0) unless (is_aarch64 && !check_var('ZDUP', '1'));
    }
    assert_script_run "sync", 300;
    power_action('reboot', textmode => 1, keepconsole => 1);

    # After remove -f for reboot, we need wait more time for boot menu and avoid exception during reboot caused delay to boot up.
    assert_screen('inst-bootmenu', 300) unless (is_s390x || is_pvm);

    # we need to stop_grub_timeout after grub shows up or it will boot into HDD sometimes.
    # for x86_64 we need to make sure the start item is installation for needle matching.
    stop_grub_timeout if is_x86_64;
    save_screenshot;
}

1;

