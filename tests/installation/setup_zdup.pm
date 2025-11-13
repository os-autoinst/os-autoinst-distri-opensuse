# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Preparation step for zypper dup. Making sure that a console is available and selected.
# Maintainer: Ludwig Nussel <lnussel@suse.com>

use base "installbasetest";
use testapi;
use utils;
use migration;
use version_utils qw(is_jeos is_desktop_installed is_leap is_opensuse);
use x11utils qw(turn_off_screensaver);
use Utils::Backends 'is_pvm';
use Utils::Architectures 'is_aarch64';
use x11utils 'default_gui_terminal';

sub run {
    my ($self) = @_;

    if (is_opensuse && is_aarch64 && get_var('PATCH_BEFORE_MIGRATION')) {
        record_info('Reboot the system and manually selecting boot entry');
        send_key 'ctrl-alt-delete';
    }
    $self->wait_boot(textmode => !is_desktop_installed(), bootloader_time => 300, ready_time => 600) unless is_jeos;
    if (get_var('ZDUP_IN_X')) {
        turn_off_screensaver;

        x11_start_program(default_gui_terminal);
        become_root;
    }
    else {
        # Remove the graphical stuff
        # This do not work in 13.2
        # script_sudo "/sbin/init 3";

        select_console('root-console');
        # Create a snapshot with specified description to do snapper rollback
        # This action is concerned about following points:
        # 1. Source image could be original installation or updated
        # 2. Source image may apply patches before migration
        # 3. Hard to assert similar snapshots in grub2
        # 4. Menu of each snapshot is long with openSUSE leap, use short and unique description
        # 5. Avoid rollback to snapshot without graphical target
        # snapper is not available at least on our version of openSUSE 13.1
        # HDD used for upgrade.
        if (get_var('HDDVERSION', '') !~ /13.1/) {
            if (script_run("mount | grep ' / ' | grep btrfs") == 0) {
                # Create a snapshot only when btrfs is used (some images do not use btrfs)
                assert_script_run "snapper create --type pre --cleanup-algorithm=number --print-number --userdata important=yes --description 'b_zdup migration'";
            }
        }

        if (!is_jeos) {
            # Remove the --force when this is fixed:
            # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
            systemctl 'set-default --force multi-user.target';
            # The CD was ejected in the bootloader test
            enter_cmd("/sbin/reboot");

            reset_consoles;
            reconnect_mgmt_console if is_pvm;
            $self->wait_boot(textmode => 1, bootloader_time => 200);

            select_console('root-console');
        }

    }
    set_zypp_single_rpmtrans;
    # starting from 15.3, core binary RPMs was inherited from SLE build directly
    # allowing the vendor change during migration is needed
    # the change below also exists in openSUSE-release package
    if (is_leap('>15.2')) {
        assert_script_run "mkdir -p /etc/zypp/vendors.d";
        assert_script_run "echo -e \"[main]\nvendors=openSUSE,SUSE,SUSE LLC\n\" > /etc/zypp/vendors.d/00-openSUSE.conf";
        clear_console;
    }

}

1;
