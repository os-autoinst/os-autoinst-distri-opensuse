# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare and trigger the reboot into the installed system
# - Change system for boot from hard disk next time
# - Select OK and reboot system
# - Keep console and reconnect VNC, unless DESKTOP is minimalx and shutdown
# timeouts
# Maintainer: QE LSG <qa-team@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use lockapi;
use testapi;
use utils;
use mmapi;
use power_action_utils 'power_action';
use Utils::Backends qw(is_pvm has_ttys);
use YuiRestClient;

sub run {
    select_console 'installation' unless get_var('REMOTE_CONTROLLER');

    # svirt: Make sure we will boot from hard disk next time
    if (check_var('VIRSH_VMM_FAMILY', 'kvm') || check_var('VIRSH_VMM_FAMILY', 'xen')) {
        my $svirt = console('svirt');
        $svirt->change_domain_element(os => boot => {dev => 'hd'});
    }
    if (get_var('USE_SUPPORT_SERVER') && get_var('USE_SUPPORT_SERVER_PXE_CUSTOMKERNEL')) {
        # we installed on a remote disk provided by a supportserver job and want
        # to reboot from this disk after downloading the bootconfig via PXE.

        my $jobid_server = (get_parents())->[0] or die "Unexpectedly no parent job found";
        if (get_var('USE_SUPPORT_SERVER_TEST_INSTDISK_MULTIPATH')) {
            # A multipath robustness test was in progress during package installation:
            # wait until the supportserver reports the tidy-up of all multipaths
            # (reference: meddle_multipaths.pm)
            mutex_wait("multipathed_iscsi_export_clean", $jobid_server);
        }
        # "supportserver: you have my system disk; please prepare a PXE menu entry with my new bootconfig"
        mutex_create("custom_pxe_client_ready", $jobid_server);
        # Await server's response "OK, done" (custom_pxeboot.pm)
        mutex_wait("custom_pxe_ready", $jobid_server);
    }
    # Reboot
    # alt-o is the "OK" button in popup "the system will reboot in X seconds..."
    if (has_ttys) {
        my $count = 0;
        while (!wait_screen_change(sub { send_key 'alt-o' }, undef, similarity_level => 20)) {
            $count < 5 ? $count++ : die "Reboot process won't start";
        }
    }
    else {
        # for now, on remote backends we need to trigger the reboot action
        # without waiting for a screen change as the remote console might
        # vanish immediately after the initial key press loosing the remote
        # socket end
        send_key 'alt-o';
    }

    if (get_var('USE_SUPPORT_SERVER') && get_var('USE_SUPPORT_SERVER_PXE_CUSTOMKERNEL')) {
        # "Press ESC for boot menu"
        # Expected: match in about 5 seconds
        assert_screen("initboot_ESC_prompt");
        send_key "esc";

        # Expected: the BIOS boot menu featuring a netboot entry
        # This boot menu appears very quickly after ESC: within 1 s:
        #
        # Select boot device:
        #
        # 1. DVD/CD ...
        # ...
        # 4. iPXE ...
        # ...
        #
        # WARNING: the PXE entry number is _volatile_!

        assert_screen("bios_bootmenu", 10);
        # Since we don't know which entry is the iPXE entry, each case needs
        # a dedicated needle with distinct secondary tag.
        # Most likely: 4, then 5
        my $pxe_found = "";
        foreach (4, 5, 3, 2, 1) {
            if (match_has_tag("bios_bootmenu_pxe_is_$_")) {
                $pxe_found = $_;
                send_key "$pxe_found";
                last;
            }
        }
        die "BIOS boot menu: unable to detect PXE entry. Giving up." unless $pxe_found;
        #
        # Expected now: the PXE boot menu with a "Custom kernel" menu entry.
        # Continuation controlled by variable 'USE_SUPPORT_SERVER_PXE_CUSTOMKERNEL': see
        #    lib/main_common.pm, sub load_reboot_tests(): loadtest "boot/boot_to_desktop"
        #    -->  boot/boot_to_desktop.pm:                $self->wait_boot(...
        #    -->  lib/opensusebasetest.pm:                $self->handle_pxeboot(...
    }
    else {
        power_action('reboot', observe => 1, keepconsole => 1, first_reboot => 1);
    }
}

1;
