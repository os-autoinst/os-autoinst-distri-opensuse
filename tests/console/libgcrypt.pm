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
use strict;
use warnings;
use version_utils qw(is_sle is_opensuse);
use registration;

sub run {
    select_console 'root-console';
    assert_script_run "rpm -q libgcrypt20";
    if (script_run("rpm -q libgcrypt-devel") == 1) {
        zypper_call "-v in gcc libgcrypt-devel", timeout => 1000;
    }

    select_console 'user-console';
    assert_script_run("test -f ~/data/libgcrypt-selftest.c || curl --create-dirs -o ~/data/libgcrypt-selftest.c " . data_url('libgcrypt-selftest.c'), 90);
    assert_script_run("gcc ~/data/libgcrypt-selftest.c -lgcrypt -o libgcrypt-selftest");
    validate_script_output("./libgcrypt-selftest", sub { /libgcrypt selftest successful/ });

    assert_script_run "libgcrypt-config --prefix";
    assert_script_run "libgcrypt-config --exec-prefix";
    assert_script_run "libgcrypt-config --version";
    assert_script_run "libgcrypt-config --api-version";
    assert_script_run "libgcrypt-config --algorithms";
}

1;
