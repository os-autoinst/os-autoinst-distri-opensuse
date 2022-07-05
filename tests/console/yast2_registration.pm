# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-registration
# Summary: check if a registered system can be re-registered and if
#          enabling and disabling extensions correctly work.
# - Install yast2-registration
# - Launch yast2 registration
# - Re-register system
# - Fill email and registration code (using system variables)
# - Enable web and scripting modules
# - Accept license agreement
# - Accept install summary
# - Accept automatic changes
# - Wait for installation report
# - Check registration status
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use registration;
use utils 'zypper_call';

sub register_system_and_add_extension {
    wait_screen_change { type_string get_var "SCC_EMAIL" };
    send_key "tab";
    wait_screen_change { type_string get_var "SCC_REGCODE" };
    send_key "alt-n";
    assert_screen("yast2_registration-ext-mod-selection", timeout => 120);
    # enable Web and Scripting Module
    for my $i (0 .. 25) {
        send_key "down";
    }
    wait_screen_change { send_key "spc" };
    send_key "alt-n";
    wait_still_screen(stilltime => 15, timeout => 60);
    if (check_screen "yast2_registration-license-agreement") {
        wait_screen_change { send_key "alt-a" };
        send_key "alt-n";
        wait_still_screen 2;
    }
    assert_screen 'yast2-software-installation-summary', 90;
    send_key "alt-a";
    wait_still_screen 2;
    assert_screen 'yast2-sw_automatic-changes';
    send_key "alt-o";
    wait_still_screen 2;
    assert_screen 'installation-report';
    wait_screen_change { send_key "alt-f" };
}

sub run {
    my ($self) = @_;

    select_console 'root-console';

    zypper_call "in yast2-registration";

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'registration');
    assert_screen 'yast2_registration-overview';
    send_key "alt-e";
    assert_screen 'yast2_registration-registration-page-registered';
    register_system_and_add_extension;
    wait_serial("$module_name-0", 200) || die "'yast2 $module_name' didn't finish";

    # Check via YaST if the system is already registered
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'registration');
    assert_screen 'yast2_registration-overview';
    send_key "alt-s";
    assert_screen 'yast2_registration-extension-registration';
}

1;

