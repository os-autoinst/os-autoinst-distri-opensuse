# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mariadb smt systemd yast2-smt SUSEConnect
# Summary: installation of smt server
# - Install smt package
# - Configure smt server
# - Use yast certificate to issue correct cert
# - Mirror repositories
# Maintainer: QE Core <qe-core@suse.com>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mm_network;
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;
    select_serial_terminal;
    barrier_create('smt_setup', 2);
    barrier_create('smt_registered', 2);
    barrier_create('smt_finished', 2);

    zypper_call 'in -t pattern smt';
    zypper_call 'in mariadb';

    select_console 'root-console';

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'smt-wizard');

    assert_screen "smt_settings";
    wait_screen_change { send_key "alt-f" };
    wait_screen_change { send_key "alt-u" };
    type_string get_var('SMT_USER');
    send_key "alt-p";
    wait_still_screen(1);
    type_string get_var('SMT_PASSWORD');
    wait_still_screen(1);
    wait_screen_change { send_key "alt-t" };
    assert_screen "smt-test-succ", 120;
    wait_screen_change { send_key "ret" };
    send_key "alt-n";
    wait_still_screen(2);

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
    wait_serial("$module_name-0", 500) || die "yast2 smt-wizard failed";

    #creating smt certificate
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'ca_mgm');
    wait_still_screen;
    assert_screen "smt-yast-ca";
    wait_still_screen(2);
    send_key "alt-e";
    wait_still_screen(2);
    type_string "susetest";
    wait_still_screen(2);
    send_key "alt-o";
    wait_still_screen(2);
    send_key "alt-e";
    wait_still_screen(2);
    send_key "alt-r";
    wait_still_screen(2);
    send_key "alt-o";
    wait_still_screen(2);
    send_key "alt-d";
    wait_still_screen(2);
    send_key "alt-o";
    wait_still_screen(2);
    send_key "alt-a";
    wait_still_screen(2);
    send_key "alt-a";
    assert_screen 'smt-ca-new-server-vertificate';
    type_string "server";
    wait_still_screen(2);
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
    send_key "alt-n";
    wait_still_screen(2);
    type_string "server";
    wait_still_screen(2);
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-u" };
    wait_screen_change { send_key "alt-n" };
    assert_screen "smt-ca-settings";
    send_key "alt-t";
    wait_still_screen(2);
    wait_screen_change { send_key "alt-x" };
    assert_screen "smt-export-ca";
    wait_screen_change { send_key "alt-p" };
    assert_screen "smt-yastca-passwd";
    wait_screen_change { send_key "alt-p" };
    wait_still_screen(2);
    type_string "susetest";
    wait_still_screen(2);
    send_key "alt-o";
    wait_still_screen(2);
    send_key "alt-o";
    wait_still_screen(2);
    wait_screen_change { send_key "alt-o" };
    wait_screen_change { send_key "alt-f" };
    wait_serial("$module_name-0", 200) || die "yast2 ca_mgm failed";


    #mirroring repos
    select_serial_terminal;
    systemctl('restart apache');
    assert_script_run "df -h";    #mirroring needs quite a lot of space
    save_screenshot;

    validate_script_output "SUSEConnect --status", sub { m/"identifier":"SLES","version":"12\.5","arch":"x86_64","status":"Registered"/ };
    assert_script_run "smt-repos -o";
    validate_script_output "smt-repos -m SLES12-SP5-Updates", sub { m/SLES12-SP5-Updates/ }, timeout => 200;

    assert_script_run "smt-repos -e SLES12-SP5-Updates sle-12-x86_64";
    assert_script_run "smt-repos -e SLES12-SP5-Pool sle-12-x86_64";
    validate_script_output "smt-repos -o", sub { m/SLES12-SP5-Updates/ };
    validate_script_output "smt-repos -o", sub { m/SLES12-SP5-Pool/ };

    assert_script_run "smt-mirror", 4000;

    assert_script_run "df -h";
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
