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
use version_utils qw(is_transactional);
use transactional qw(trup_call check_reboot_changes);
use serial_terminal qw(select_user_serial_terminal);

our @EXPORT = qw(install_bats add_packagehub remove_mounts_conf switch_to_user);

sub install_bats {
    return if (script_run("which bats") == 0);

    my $bats_version = get_var("BATS_VERSION", "1.11.0");

    script_retry("curl -sL https://github.com/bats-core/bats-core/archive/refs/tags/v$bats_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd bats-core-$bats_version";
    assert_script_run "bash ./install.sh /usr/local";
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
