# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Common functions for BATS test suites
# Maintainer: qa-c@suse.de

package containers::bats;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils;
use registration qw(add_suseconnect_product get_addon_fullname);
use transactional qw(trup_call check_reboot_changes);
use serial_terminal qw(select_user_serial_terminal);

our @EXPORT = qw(add_packagehub remove_mounts_conf switch_to_user);

sub add_packagehub {
    if (is_sle_micro) {
        my $sle_version = "";
        if (is_sle_micro('<5.3')) {
            $sle_version = "15.3";
        } elsif (is_sle_micro('<5.5')) {
            $sle_version = "15.4";
        } elsif (is_sle_micro('<6.0')) {
            $sle_version = "15.5";
        }
        trup_call "register -p PackageHub/$sle_version/" . get_required_var('ARCH');
        zypper_call "--gpg-auto-import-keys ref";
    } elsif (is_sle) {
        add_suseconnect_product(get_addon_fullname('phub'));
    }
}

sub remove_mounts_conf {
    if (script_run("test -f /etc/containers/mounts.conf -o -f /usr/share/containers/mounts.conf") == 0) {
        if (is_transactional) {
            trup_call "run rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";
            check_reboot_changes;
        } else {
            script_run "rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";
        }
    }
}

sub switch_to_user {
    if (script_run("grep $testapi::username /etc/passwd") != 0) {
        my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
        assert_script_run "useradd -m -G $serial_group $testapi::username";
        assert_script_run "echo '${testapi::username}:$testapi::password' | chpasswd";
        ensure_serialdev_permissions;
        select_console "user-console";
    } else {
        select_user_serial_terminal();
    }
}
