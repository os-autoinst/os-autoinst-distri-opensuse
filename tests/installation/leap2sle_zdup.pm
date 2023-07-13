# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Those are steps for leap to sle zypper dup. Includes: switch to a tty, full patch
# leap system, install SUSEConnect, Register at SCC to get SLE repo, List and disable all
# openSUSE repo, add modules need for installation, Migrate installed packages to SLES repo,
# Remove orphaned packages, reboot the system
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use registration;
use version_utils qw(is_desktop_installed is_leap);
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;

    $self->wait_boot(textmode => !is_desktop_installed(), bootloader_time => 300, ready_time => 600);

    select_console('root-console');
    # We need to install rollback-helper and enable/start rollback.service
    # before creating a snapshot.
    zypper_call 'in rollback-helper';
    systemctl("enable rollback");
    systemctl("start rollback");
    # Create a snapshot with specified description to do snapper rollback
    assert_script_run "snapper create --type pre --cleanup-algorithm=number --print-number --userdata important=yes --description 'b_zdup migration'";

    systemctl 'set-default --force multi-user.target';
    fully_patch_system();
    # SUSEConnect is obsoleted and provided by suseconnect-ng from 15.4
    zypper_call 'in SUSEConnect' if is_leap("<=15.3");
    my $version = get_var("VERSION");
    $version =~ s/\-SP/./;
    add_suseconnect_product("SLES", $version, get_var("ARCH"), " -r " . get_var("SCC_REGCODE"), 300, 1);
    zypper_call 'lr';
    zypper_call '-n mr --all --disable';
    assert_script_run "SUSEConnect --list-extensions";
    register_product();
    register_addons_cmd("base,serverapp,legacy,desktop,phub");
    zypper_call('dup --force-resolution', timeout => 1800);
    zypper_call "rm \$(zypper --no-refresh packages --orphaned | gawk '{print \$5}' | tail -n +5)";
    if (is_desktop_installed) {
        systemctl 'set-default graphical.target';
    }
    power_action('reboot', keepconsole => 1, textmode => 1);
}

1;
