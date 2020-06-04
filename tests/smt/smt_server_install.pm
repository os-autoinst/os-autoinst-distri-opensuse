# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: installation of smt server
# - Install smt package
# - Configure smt server
# - Use yast certificate to issue correct cert
# - Mirror repositories
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mm_network;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    zypper_call 'in -t pattern smt';
    zypper_call 'in mariadb';

    assert_script_run 'hostnamectl set-hostname server';

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'smt-wizard');

    wait_still_screen;
    wait_screen_change { send_key "alt-f" };
    wait_screen_change { send_key "alt-u" };
    type_string "UC5414818";
    wait_screen_change { send_key "alt-p" };
    type_string "2c3dff7ee9";

    wait_screen_change { send_key "alt-s" };
    type_string 'osukup@suse.com';
    wait_screen_change { send_key "alt-y" };
    foreach (0 .. 15) {
        wait_screen_change { send_key "backspace" };
    }
    type_string "http://server/";
    assert_screen "smt_settings";

    wait_screen_change { send_key "alt-t" };
    assert_screen "smt-test-succ";
    wait_screen_change { send_key "ret" };
    wait_screen_change { send_key "alt-n" };

    wait_screen_change { send_key "alt-d" };
    type_string "susetest";
    wait_screen_change { send_key "alt-s" };
    type_string "susetest";
    wait_screen_change { send_key "alt-n" };

    assert_screen "smt-mariadb";
    wait_screen_change { send_key "alt-p" };
    type_string "susetest";
    wait_screen_change { send_key "alt-a" };
    type_string "susetest";
    wait_screen_change { send_key "alt-o" };

    assert_screen "smt-cert";
    wait_screen_change { send_key "alt-r" };

    assert_screen "smt-ca-passwd";
    wait_screen_change { send_key "alt-p" };
    type_string "susetest";
    wait_screen_change { send_key "alt-n" };
    type_string "susetest";
    wait_screen_change { send_key "alt-o" };

    wait_screen_change { send_key "alt-n" };
    wait_still_screen(7, 45);
    wait_screen_change(sub { }, 360);
    $self->clear_and_verify_console;

    #creating smt certificate
    script_run("yast ca_mgm", timeout => 0);
    wait_still_screen;
    assert_screen "smt-yast-ca";
    wait_screen_change { send_key "alt-e" };
    type_string "susetest";
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-e" };
    wait_screen_change { send_key "alt-r" };
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-d" };
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-a" };
    wait_screen_change { send_key "alt-a" };
    type_string "server";
    wait_screen_change { send_key "alt-n" };
    wait_screen_change { send_key "alt-a" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "ret" };
    wait_screen_change { send_key "alt-a" };
    wait_screen_change { send_key "alt-d" };
    wait_screen_change { send_key "alt-n" };
    type_string "server";
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-u" };
    wait_screen_change { send_key "alt-n" };
    assert_screen "smt-ca-settings";
    wait_screen_change { send_key "alt-t" };
    wait_still_screen(3, 45);
    wait_screen_change { send_key "alt-x" };
    assert_screen "smt-export-ca";
    wait_screen_change { send_key "alt-p" };
    wait_screen_change { send_key "alt-p" };
    assert_screen "smt-yastca-passwd";
    type_string "susetest";
    wait_screen_change { send_key "alt-o" };
    wait_still_screen;
    wait_screen_change { send_key "alt-o" };
    wait_still_screen;
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-f" };
    $self->clear_and_verify_console;

    #mirroring repos
    assert_script_run "df -h";    #mirroring needs quite a lot of space
    save_screenshot;

    validate_script_output "SUSEConnect --status", sub { m/"identifier":"SLES","version":"12\.5","arch":"x86_64","status":"Registered"/ };
    assert_script_run "smt-repos -o";
    validate_script_output "smt-repos -m", sub { m/SLES12-SP5-Updates/ };

    assert_script_run "smt-repos -e SLES12-SP5-Updates sle-12-x86_64";
    assert_script_run "smt-repos -e SLES12-SP5-Pool sle-12-x86_64";
    validate_script_output "smt-repos -o", sub { m/SLES12-SP5-Updates/ };
    validate_script_output "smt-repos -o", sub { m/SLES12-SP5-Pool/ };

    assert_script_run "smt-mirror", 16000;

    assert_script_run "df -h";
    save_screenshot;
    select_console "x11";
}
1;
