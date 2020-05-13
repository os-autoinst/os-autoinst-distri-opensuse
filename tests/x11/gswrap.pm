# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gswrap test
# Test case for gswrap package for ghostscript
# see https://progress.opensuse.org/issues/56003
# install and check gswrap package for ghostscript
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use Utils::Backends 'use_ssh_serial_console';
use strict;
use warnings;

sub run {
    check_var("BACKEND", "ipmi") ? use_ssh_serial_console : select_console 'root-console';
    zypper_call("in ghostscript ghostscript-x11 gswrap");
    # check and open an example file
    select_console('x11');
    x11_start_program('xterm');
    # we can check some stuff if needed
    # type_string("xauth list \n");
    # save_screenshot;
    # type_string("echo \">>\$DISPLAY<< >>\$XAUTHORITY<<\" \n");
    # type_string("ls -l /usr/bin/gs \n");
    # type_string("ls -l /etc/alternatives/gs \n");
    # save_screenshot;
    # type_string("gs --help | grep device: \n");
    # type_string("ls -A /tmp \n");
    # save_screenshot;
    # type_string("bash -x gs.wrap -dSAFER \n");
    type_string("ps auxe | grep xterm | sed -rn 's/.*(DISPLAY=[^[:blank:]]+).*/\\1/p' \n");
    type_string("echo \$DISPLAY \n");
    save_screenshot;
    type_string("/usr/bin/gs.wrap -sDEVICE=x11alpha -g600x400 /usr/share/ghostscript/`gs --version`/examples/waterfal.ps \n");
    # save_screenshot;
    assert_screen "gswrap";
}

1;
