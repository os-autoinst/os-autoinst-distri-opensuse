# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test for the yast2-rmt module
# Maintainer: Jonathan Rivrain <JRivrain@suse.com>

use base "console_yasttest";
use strict;
use warnings;
use utils;
use testapi;


sub password_twice {
    type_password;
    send_key "tab";
    type_password;
    send_key "alt-o";
}

sub test_ui {
    script_run("yast2 rmt; echo yast2-rmt-server-status-\$? > /dev/$serialdev", 0);
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
    password_twice;
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
    password_twice;
    assert_screen "yast2_rmt_firewall";
    send_key "spc";
    send_key "alt-n";
    assert_screen "yast2_rmt_service_status";
    send_key "alt-n";
    assert_screen "yast2_rmt_config_summary";
    send_key "alt-f";
    wait_serial('yast2-rmt-server-status-0', 60) || die "'yast2 rmt' didn't finish";
}

sub test_config {
    my @unit = ("rmt-server.service", "rmt-server-sync.timer", "rmt-server-mirror.timer");
    for (@unit) {
        script_run("systemctl is-active $_") && die "The systemd unit $_ is not active";
    }
    script_run("firewall-cmd --list-services |egrep 'http[[:space:]]https'")            && die "The firewall ports are not opened";
    script_run("grep rmt /etc/rmt.conf")                                                && die "Missing values in /etc/rmt.conf";
    script_run("wget --no-check-certificate https://localhost/rmt.crt")                 && die "Certificate not found at https://localhost/rmt.crt";
    script_run("openssl x509 -noout -subject -in 'rmt.crt' | grep 'rmt1.susetest.org'") && die "Incorrect name in certificate ?";
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
