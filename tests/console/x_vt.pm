# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check for correct tty used by X
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_tumbleweed is_leap is_sle);

sub run {
    # First, list all X processes, including user process and gdm process
    script_run("ps -ef | grep -E 'bin/X|/gnome-session'");
    if (script_run("ps -ef | grep bin/X | grep -E 'tty7|wayland'") == 1) {
        if (check_var('DESKTOP', 'gnome')
            && (is_tumbleweed || is_leap('>=15.2') || is_sle('>=15-SP2'))
            && script_run("ps -ef | grep -E 'bin/X|/gnome-session' | grep tty2") == 0) {
            diag('user session runs on tty2 for systems with GNOME 3.32+, see boo#1138327');
        }
        else {
            die 'Graphical session not found on tty7';
        }
    }
}

1;
