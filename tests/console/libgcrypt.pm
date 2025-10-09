# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libgcrypt20 gcc libgcrypt-devel
# Summary: test that libgcrypt works as intended by executing
#          the selftest and by calling libgcrypt-config.
#          In addition to this test, also the gpg test should be
#          checked by tester because gpg uses libgcrypt.
# - execute libgcrypt self test
# - using libgcrypt-config, check some parameters
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "opensusebasetest";
use testapi;
use utils;
use version_utils qw(is_sle is_opensuse);
use serial_terminal qw(select_serial_terminal);
use registration;

sub run {
    select_serial_terminal;
    assert_script_run "rpm -q libgcrypt20";
    if (script_run("rpm -q libgcrypt-devel") == 1) {
        zypper_call "-v in gcc libgcrypt-devel", timeout => 1000;
    }
    ensure_serialdev_permissions;
    # 0 -> 'False' means login as plain user
    select_serial_terminal(0);
    assert_script_run("test -f ~/data/libgcrypt-selftest.c || curl --remote-name --create-dirs --output-dir ~/data " . data_url('libgcrypt-selftest.c'), 90);
    assert_script_run("gcc ~/data/libgcrypt-selftest.c -lgcrypt -o libgcrypt-selftest");
    validate_script_output("./libgcrypt-selftest", sub { /libgcrypt selftest successful/ });

    assert_script_run "libgcrypt-config --prefix";
    assert_script_run "libgcrypt-config --exec-prefix";
    assert_script_run "libgcrypt-config --version";
    assert_script_run "libgcrypt-config --api-version";
    assert_script_run "libgcrypt-config --algorithms";
}

1;
