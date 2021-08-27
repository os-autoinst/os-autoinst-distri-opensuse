# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for correct tty used by X
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_tumbleweed is_leap is_sle);

sub run {
    # First, list all X processes, including user process and gdm process
    script_run('ps -ef | grep bin/X');
    if (script_run("ps -ef | grep bin/X | egrep 'tty7|wayland'") == 1) {
        if ((is_tumbleweed || is_leap('>=15.2') || is_sle('>=15-SP2')) && script_run('ps -ef | grep bin/X | grep tty2') == 0) {
            diag('user X process runs on tty2 for systems with GNOME 3.32+, see boo#1138327');
        }
        else {
            die 'Expected tty7 used by X or wayland not found';
        }
    }
}

1;
