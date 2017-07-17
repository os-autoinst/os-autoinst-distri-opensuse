# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check /lib/libc.so.* content
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils 'zypper_call';

# this part contains the steps to run this test
sub run {
    select_console 'root-console';

    zypper_call 'in -C libc.so.6';
    script_run "/lib/libc.so.* | tee /dev/$serialdev", 0;
    wait_serial("\QGNU C Library (GNU libc) stable release\E.*\n.*\n.*\n.*\n.*\n\QConfigured for i686-suse-linux.\E") || die '/lib/libc.so.* did not match';
}

1;
# vim: set sw=4 et:
