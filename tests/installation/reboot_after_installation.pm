# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare and trigger the reboot into the installed system
# - Change system for boot from hard disk next time
# - Select OK and reboot system
# - Keep console and reconnect VNC, unless DESKTOP is minimalx and shutdown
# timeouts
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use lockapi;
use testapi;
use utils;
use mmapi;
use power_action_utils 'power_action';
use Utils::Backends 'has_ttys';

sub run {
    select_console 'installation' unless get_var('REMOTE_CONTROLLER');

    # svirt: Make sure we will boot from hard disk next time
    if (check_var('VIRSH_VMM_FAMILY', 'kvm') || check_var('VIRSH_VMM_FAMILY', 'xen')) {
        my $svirt = console('svirt');
        $svirt->change_domain_element(os => boot => {dev => 'hd'});
    }
    if (get_var('SUPPORT_SERVER_PXE_CUSTOMKERNEL')) {
        # we installed on a remote disk provided by a supportserver job and want
        # to reboot from this disk after downloading the bootconfig via PXE.

        my $jobid_server = (get_parents())->[0] or die "Unexpectedly no parent job found";
        # "supportserver: please prepare a PXE menu entry with my new bootconfig"
        mutex_create("custom_pxe_client_ready", $jobid_server);
        # Wait until the server responds "Got it" (custom_pxeboot.pm)
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
    if (get_var('SUPPORT_SERVER_PXE_CUSTOMKERNEL')) {
        # "Press ESC for boot menu"
        # Expected: match in about 5 seconds
        assert_screen("initboot_ESC_prompt", 10);
        send_key "esc";

        # Expected: the BIOS boot menu featuring a netboot entry
        # This boot menu appears very quickly after ESC: within 1 s:
        #
        # Select boot device:
        #
        # 1. DVD/CD ...
        # 2. Floppy ...
        # 3. Virtio disk ...
        # 4. iPXE ...
        # 5. Legacy option rom
        #
        # WARNING: the PXE entry number is _volatile_!

        assert_screen("bios_bootmenu", 10);
        # Since we don't know which entry is the iPXE entry, each case needs
        # a dedicated needle with distinct secondary tag
        # Most probable results: 4, then 5
        # FIXME: as of now, only needle for 4 exists.
        if (match_has_tag("bios_bootmenu_pxe_is_4")) {
            send_key "4";
        }
        elsif (match_has_tag("bios_bootmenu_pxe_is_5")) {
            send_key "5";
        }
        elsif (match_has_tag("bios_bootmenu_pxe_is_3")) {
            send_key "3";
        }
        elsif (match_has_tag("bios_bootmenu_pxe_is_2")) {
            send_key "2";
        }
        elsif (match_has_tag("bios_bootmenu_pxe_is_1")) {
            send_key "1";
        }
        else {
            die "BIOS boot menu: unable to detect PXE entry. Giving up.";
        }
        #
        # Expected now: the PXE boot menu with a "custom kernel" menu entry.
        # Continuation: in boot_from_pxe.pm
        # (see lib/main_common.pm, sub load_reboot_tests())
        # beginning with: assert_screen("pxe-custom-kernel", 40);
    }
    else {
        power_action('reboot', observe => 1, keepconsole => 1, first_reboot => 1);
    }
}

1;
