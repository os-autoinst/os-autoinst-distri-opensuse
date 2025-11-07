# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: glibc glibc-32bit
# Summary: Check /lib{,64}/libc.so.6 provides correct content
# - Install package providing "libc.so.6"
# - Check "/lib/libc.so.6" for "GNU C Library"
# - Check "/lib/libc.so.6" for "i686-suse-linux"
# - Install package providing "libc.so.6()(64bit)"
# - Check "/lib64/libc.so.6" for "GNU C Library"
# - Check "/lib64/libc.so.6" for "x86_64-suse-linux" (or whatever arch is set)
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use Utils::Architectures;
use utils 'zypper_call';
use version_utils qw(is_sle is_leap);

sub run {
    select_console 'root-console';

    my $libcstr = 'GNU C Library';
    if (is_x86_64 && !(is_sle('16+') || is_leap("16+"))) {
        # On Tumbleweed we still support 32-bit x86
        zypper_call 'in -C libc.so.6';
        assert_script_run "/lib/libc.so.6 | tee /dev/$serialdev | grep --color '$libcstr'";
        assert_script_run '/lib/libc.so.6 | grep --color "i686-suse-linux"';
    }
    if (is_x86_64 || is_aarch64) {
        zypper_call 'in -C "libc.so.6()(64bit)"';
        assert_script_run "/lib64/libc.so.6 | tee /dev/$serialdev | grep --color '$libcstr'";
        assert_script_run '/lib64/libc.so.6 | grep --color "' . get_var('ARCH') . '-suse-linux"';
    }
}

1;
