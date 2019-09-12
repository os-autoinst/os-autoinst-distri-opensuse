# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
        zypper_call "in gcc libgcrypt-devel";
    }

    select_console 'user-console';
    assert_script_run("gcc ~/data/libgcrypt-selftest.c -lgcrypt -o libgcrypt-selftest");
    validate_script_output("./libgcrypt-selftest", sub { /libgcrypt selftest successful/ });

    assert_script_run "libgcrypt-config --prefix";
    assert_script_run "libgcrypt-config --exec-prefix";
    assert_script_run "libgcrypt-config --version";
    assert_script_run "libgcrypt-config --api-version";
    assert_script_run "libgcrypt-config --algorithms";
}

1;
