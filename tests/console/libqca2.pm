# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
    script_run "$qca_cmd cert makeself rsapriv.pem --pass=suse";
    type_string "tester\n";
    type_string "DE\n";
    type_string "SUSE\n";
    type_string "tester\@suse.com\n";
    type_string "1y\n";

    assert_script_run "$qca_cmd show cert cert.pem";
    assert_script_run "$qca_cmd keybundle make rsapriv.pem cert.pem --pass=suse --newpass=suse";
    assert_script_run "$qca_cmd keystore list-stores";
    script_run "$qca_cmd keystore monitor";
    type_string "q\n";
    assert_script_run "$qca_cmd show kb cert.p12 --pass=suse";

    script_run "rm -f cert.pem rsapriv.pem rsapub.pem";
}

1;
