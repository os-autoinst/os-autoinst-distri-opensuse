# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check /lib{,64}/libc.so.6 provides correct content
# - Install package providing "libc.so.6"
# - Check "/lib/libc.so.6" for "GNU C Library"
# - Check "/lib/libc.so.6" for "i686-suse-linux"
# - Install package providing "libc.so.6()(64bit)"
# - Check "/lib64/libc.so.6" for "GNU C Library"
# - Check "/lib64/libc.so.6" for "x86_64-suse-linux"
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    my $libcstr = 'GNU C Library';
    zypper_call 'in -C libc.so.6';
    assert_script_run "/lib/libc.so.6 | tee /dev/$serialdev | grep --color '$libcstr'";
    assert_script_run '/lib/libc.so.6 | grep --color "i686-suse-linux"';
    return if !check_var('ARCH', 'x86_64');    # On Tumbleweed we still support 32-bit x86
    zypper_call 'in -C "libc.so.6()(64bit)"';
    assert_script_run "/lib64/libc.so.6 | tee /dev/$serialdev | grep --color '$libcstr'";
    assert_script_run '/lib64/libc.so.6 | grep --color "x86_64-suse-linux"';
}

1;
