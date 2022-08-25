# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libqca-qt5 libqca-qt5-devel libqca2 libqca2-devel
# Summary: test qcatool commands
# - check program version
# - list plugins
# - create new rsa key
# - create new cert
# - show cert
# - bundle key and cert
# - list stores
# - monitor keystore
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "opensusebasetest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils qw(is_sle is_leap is_tumbleweed);
use registration qw(add_suseconnect_product register_product);

sub run {
    select_console 'root-console';
    if (is_tumbleweed || is_leap) {
        zypper_call("in libqca-qt5 libqca-qt5-devel", timeout => 600);
    } else {
        add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1) if is_sle(">=15");
        zypper_call("in libqca2 libqca2-devel", timeout => 600);
    }

    my $qca_cmd;
    if (is_sle("<15")) {
        $qca_cmd = "qcatool2";
    }
    if (is_sle(">=15")) {
        $qca_cmd = "qcatool";
    }
    if (is_tumbleweed || is_leap) {
        $qca_cmd = "qcatool-qt5";
    }

    assert_script_run "$qca_cmd version";
    assert_script_run "$qca_cmd plugins";
    assert_script_run "$qca_cmd plugins --debug";
    assert_script_run "$qca_cmd key make rsa 1024 --newpass=suse";
    enter_cmd "$qca_cmd cert makeself rsapriv.pem --pass=suse";
    enter_cmd "tester";
    enter_cmd "DE";
    enter_cmd "SUSE";
    enter_cmd "tester\@suse.com";
    enter_cmd "1y";

    assert_script_run "$qca_cmd show cert cert.pem";
    assert_script_run "$qca_cmd keybundle make rsapriv.pem cert.pem --pass=suse --newpass=suse";
    assert_script_run "$qca_cmd keystore list-stores";
    enter_cmd "$qca_cmd keystore monitor";
    assert_screen "qctool2_keystore_monitor";
    enter_cmd "q";
    assert_script_run "$qca_cmd show kb cert.p12 --pass=suse";

    script_run "rm -f cert.pem rsapriv.pem rsapub.pem";
}

1;
