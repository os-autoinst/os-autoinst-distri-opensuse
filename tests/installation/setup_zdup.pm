# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Preparation step for zypper dup. Making sure that a console is available and selected.
# Maintainer: Ludwig Nussel <lnussel@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_jeos is_desktop_installed is_leap);
use Utils::Backends 'is_pvm';

sub run {
    my ($self) = @_;

    $self->wait_boot(textmode => !is_desktop_installed(), bootloader_time => 300, ready_time => 600) unless is_jeos;
    if (get_var('ZDUP_IN_X')) {
        x11_start_program('xterm');
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
            assert_script_run "snapper create --type pre --cleanup-algorithm=number --print-number --userdata important=yes --description 'b_zdup migration'";
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
