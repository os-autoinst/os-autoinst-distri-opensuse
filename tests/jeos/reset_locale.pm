# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Reset locale to en_US.UTF-8 if it was changed during JeOS installation
# Maintainer: QE-C team <qa-c@suse.de>

use base "opensusebasetest";
use testapi;
use jeos qw(is_translations_preinstalled);
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    select_console 'root-console';

    assert_script_run("localectl set-locale LANG=en_US.UTF-8") if is_translations_preinstalled() && get_var('JEOSINSTLANG') && (get_var('JEOSINSTLANG') ne 'en_US');
    # DESKTOP can be gnome, but patch is happening in shell, thus always force reboot in shell
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(ready_time => 600, bootloader_time => get_var('BOOTLOADER_TIMEOUT', 300));
}

sub test_flags {
    return {fatal => 1};
}

1;
