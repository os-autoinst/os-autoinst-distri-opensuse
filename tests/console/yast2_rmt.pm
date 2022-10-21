# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rmt-server yast2-rmt
# Summary: Test for the yast2-rmt module
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent "y2_module_consoletest";

use strict;
use warnings;
use utils;
use testapi;
use repo_tools;

sub password_twice {
    type_password;
    send_key "tab";
    type_password;
    send_key "alt-o";
}

sub test_ui {
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'rmt');
    assert_screen "yast2_rmt_registration";
    send_key "alt-n";
    assert_screen "yast2_rmt_ignore_registration_dialog";
    send_key "alt-i";
    send_key "ret";
    assert_screen "yast2_rmt_db_password";
    send_key "alt-p";
    type_password;
    send_key "alt-n";
    assert_screen "yast2_rmt_db_root_password";
    type_password_twice;
    assert_screen "yast2_rmt_config_written_successfully";
    send_key "alt-o";
    assert_screen "yast2_rmt_ssl";
    send_key "alt-o";
    # Try to avoid creating lots of screenshots, but still use send_key_until_needlematch "just in case".
    for (1 .. 15) { send_key "backspace" }
    send_key_until_needlematch('yast2_rmt_common_name_empty', 'backspace');
    type_string "rmt1.susetest.org";
    send_key "alt-d";
    assert_screen "yast2_rmt_ssl_add_name";
    type_string "localhost";
    send_key "alt-o";
    send_key "alt-n";
    assert_screen "yast2_rmt_ssl_CA_password";
    type_password_twice;
    assert_screen "yast2_rmt_firewall";
    send_key "spc";
    send_key "alt-n";
    assert_screen "yast2_rmt_service_status";
    wait_still_screen;
    send_key "alt-n";
    assert_screen "yast2_rmt_config_summary";
    send_key "alt-f";
    wait_serial("$module_name-0", 60) || die "'yast2 rmt' didn't finish";
}

sub test_config {
    my @unit = ("rmt-server.service", "rmt-server-sync.timer", "rmt-server-mirror.timer");
    for (@unit) {
        script_run("systemctl is-active $_") && die "The systemd unit $_ is not active";
    }
    assert_script_run("firewall-cmd --list-services |grep -E 'http[[:space:]]https'", fail_message => 'The firewall ports are not opened');
    assert_script_run("grep rmt /etc/rmt.conf", fail_message => 'Missing values in /etc/rmt.conf');
    assert_script_run("wget --no-check-certificate https://localhost/rmt.crt", fail_message => 'Certificate not found at https://localhost/rmt.crt');
    # yast2-rmt was changed to no longer include the host name as part of the CA
    assert_script_run("openssl x509 -noout -subject -in 'rmt.crt' | grep 'RMT Certificate Authority'", fail_message => 'Incorrect CN name in the certificate');
}

sub run {
    select_console 'root-console';
    zypper_call("in rmt-server yast2-rmt");
    test_ui;
    test_config;
    # Remove rmt-server and nginx to avoid conflict with yast2_http
    zypper_call("rm rmt-server yast2-rmt nginx");
    assert_script_run("firewall-cmd --remove-service=http{,s}");
}


1;
