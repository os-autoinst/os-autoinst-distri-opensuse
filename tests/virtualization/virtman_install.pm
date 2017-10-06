# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Virtualization virtman installation setup
# Maintainer: aginies <aginies@suse.com>

use base "x11test";
use strict;
use testapi;


sub run {
    #ensure_installed("virt-manager");
    # workaround for bug:
    # Bug 948366 - "pkcon install virt-manager" report it will remove
    # the package if this command is run twice
    x11_start_program('xterm', target_match => 'xterm');
    become_root();
    script_run "zypper -n in virt-manager";
    # exit root, and be the default user
    type_string "exit\n";
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:

