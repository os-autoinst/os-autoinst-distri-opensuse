# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot on UEFI systems with configuration of boot parameters
# - If system is DUALBOOT, call tianocore_select_bootloader (tianocore boot
# menu) and choose dvd boot
# - If aarch64 tianocore, raise delay to 60s
# - If "UEFI_HTTP_BOOT" or "UEFI_HTTPS_BOOT" are defined, call
# tianocore_http_boot (tianocore boot menu, choose network boot via http or
# https
# - If "ZDUP" is defined, boot using harddisk. In case of aarch64, call
# handle_uefi_boot_disk_workaround (select hard disk from tianocore menu)
# - If "UPGRADE" is defined, go to upgrade option on bootloader
# - Or if "PROMO", "LIVETEST" or "LIVECD" are defined, boot desktop
# option.
# - Otherwise, if it is not "is_jeos" and not "VMX", boot installation option.
# - Call uefi_bootmenu_params (1024x768 graphics mode, "install=" if NETBOOT or
# "textmode=1" if VIDEOMODE="text")
# - Call bootmenu_default_params (Edit grub parameters, add "Y2DEBUG=1",
# graphics mode and resolution, serial output, console/log redirection)
# - Call specific_bootmenu_params (Autoyast options, network options, debug
# options, installer specific options, fips enablement, kexec parameters, addon
# products, DUD loading, external ISO) unless it is is_microos or is_jeos
# - Save bootloader parameters in a screenshot
# - if "USE_SUPPORT_SERVER" is defined, wait for mutex to unlock before sending
# "F10"
# Maintainer: QE LSG <qa-team@suse.de>

package bootloader_uefi;

use base "installbasetest";

use Time::HiRes 'sleep';

use testapi;
use Utils::Architectures;
use lockapi 'mutex_wait';
use bootloader_setup;
use registration;
use utils;
use version_utils qw(is_jeos is_microos is_opensuse is_sle is_selfinstall is_sle_micro is_leap_micro is_bootloader_sdboot is_bootloader_grub2_bls is_transactional);
use Utils::Backends qw(is_ipmi);

# hint: press shift-f10 trice for highest debug level
sub run {
    my ($self) = @_;

    # Press key 't' to let grub2 boot menu show up in serial console
    if (is_ipmi && current_console eq 'sol' && is_selfinstall && get_var('IPXE_UEFI')) {
        assert_screen('press-t-for-boot-menu', 180);
        sleep 5;
        send_key('t', wait_screen_change => 1);
    }

    # Enabled boot menu for x86_64 uefi. In migration cases we set cdrom as boot index=0
    # However migration cases need to boot the hard disk and fully pach it which are the
    # testing requirements. So we keep this logic to boot the hard disk directly instead
    # of cdrom boot menu entry
    # Case setting also need BOOT_MENU=1 to support it
    if (is_sle && get_required_var('FLAVOR') =~ /Migration/ && is_x86_64) {
        # Skip workaround on specific scenaio which call this module after migration
        if (!check_screen('bootloader-grub2', 0, no_wait => 1)) {
            tianocore_select_bootloader;
            send_key_until_needlematch("ovmf-boot-HDD", 'down', 6, 1);
            send_key "ret";
            return;
        }
    }

    if (get_var("IPXE") && !is_usb_boot) {
        sleep 60;
        return;
    }

    if (get_var('DUALBOOT')) {
        tianocore_select_bootloader;
        send_key_until_needlematch('tianocore-bootmanager-dvd', 'down', 6, 5);
        send_key "ret";
    }

    # Skip to load bootloader in test of online migration on aarch64
    # Handle aarch64 image boot by wait_boot called in setup_online_migration
    if (get_var('ONLINE_MIGRATION') && is_aarch64) {
        return;
    }

    # aarch64 firmware 'tianocore' can take longer to load
    my $bootloader_timeout = is_aarch64 ? 90 : 25;
    $bootloader_timeout += 90 if get_var('FLAVOR', '') =~ /encrypted/i;
    if (get_var('UEFI_HTTP_BOOT') || get_var('UEFI_HTTPS_BOOT')) {
        tianocore_http_boot;
    }

    # Some aach64 JeOS jobs take too long to match the first grub2 needle.
    # By pressing a random key, we stop the grub timeout
    send_key 'backspace' if (is_aarch64 && (is_sle_micro('6.0+') || is_jeos));

    if (get_var('FLAVOR') =~ /VMware-Updates/) {
        # VMware guests have a short GRUB timeout, which can cause issues with needle matching.
        # After the VMware guest boots to the OS, we press the left arrow key to stop the GRUB timeout.
        assert_screen('bootloader-vmware');
        record_info('Flavor is VMWare-Updates', 'Flavor is VMWare-Updates');
        wait_screen_change(sub { sleep(0.1); }, 90, similarity_level => 20);
        send_key 'left';
    }

    if (get_var('VERSION') =~ /agama/) {
        # For agama test, it is too short time to match the grub2(10s), so we create
        # a new needle to avoid too much needles loaded.
        assert_screen("bootloader-grub2-agama", $bootloader_timeout);
    }
    else {
        assert_screen([qw(bootloader-shim-import-prompt bootloader-grub2 grub2-bls bootloader-sdboot)], $bootloader_timeout);
    }
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
        assert_screen([qw(bootloader-grub2 bootloader-sdboot grub2-bls)], $bootloader_timeout);
    }
    if (match_has_tag("bootloader-sdboot")) {
        return if is_bootloader_sdboot;
    }

    if (match_has_tag('grub2-bls') && is_bootloader_grub2_bls) {
        return;
    }

    my $efi_vars_have_nosb = get_var('UEFI_PFLASH_VARS', '') =~ /nosb/i;
    if (!$efi_vars_have_nosb && get_var('DISABLE_SECUREBOOT') && (get_var('BACKEND') eq 'qemu')) {
        $self->tianocore_disable_secureboot;
    }
    if ((get_var("ZDUP") && !is_jeos) || (get_var('ONLINE_MIGRATION') && check_var('BOOTFROM', 'd'))) {
        # 'eject_cd' is broken ATM (at least on aarch64), so select HDD from menu - poo#47303
        # Check we are booting the ISO
        assert_screen 'inst-bootmenu';
        # Select boot from HDD
        send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
        send_key 'ret';
        # use firmware boot manager of aarch64 and uefi to boot HDD
        $self->handle_uefi_boot_disk_workaround if (is_aarch64 || get_var('UEFI'));
        assert_screen("grub2");
        return;
    }

    if (get_var("UPGRADE")) {
        # random magic numbers
        send_key_until_needlematch('inst-onupgrade', 'down', 11, 3);
    }
    elsif (get_var('VERSION') !~ /agama/) {
        if (get_var("PROMO") || get_var('LIVETEST') || get_var('LIVECD')) {
            send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 11, 3);
        } elsif (get_var("AGAMA")) {
            select_bootmenu_option;
        } elsif (is_sle('>=16') && is_transactional) {
            goto INST_BOOTMENU;
        } elsif (!(is_jeos || ((is_sle_micro || is_leap_micro) && !is_selfinstall)) && !is_microos('VMX')) {
            send_key_until_needlematch('inst-oninstallation', 'down', 11, 0.5);
        }
    }
  INST_BOOTMENU:

    uefi_bootmenu_params;

    # Ipmi backend sol console is not reliable enough to change bootmenu params,
    # so skip bootmenu_default_params which is not necessary now.
    # However, serial console and INST_AUTO settings are actually useful.
    # If agama provides support for installation via ssh connection or others,
    # we will then consider adding them back.
    if (is_ipmi && is_uefi_boot && is_selfinstall) {
        # Directly start installation
        if (check_var("CTRL_X_TO_BOOT", "1")) {
            send_key "ctrl-x";
        } else {
            send_key "f10";
        }
        wait_still_screen;
        return;
    }

    bootmenu_default_params(in_grub_edit => 1);
    save_screenshot();
    unless (is_selfinstall) {
        bootmenu_remote_target;
        specific_bootmenu_params unless is_microos || is_jeos;

        # JeOS is never deployed with Linuxrc involved,
        # so 'regurl' does not apply there.
        registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED) unless is_jeos || (is_sle_micro && get_var('BOOT_HDD_IMAGE')) || is_opensuse;

        # boot
        mutex_wait 'support_server_ready' if get_var('USE_SUPPORT_SERVER');
    }
    send_key "f10";
}

1;
