# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: xterm
# Summary: Basic functionality of xterm terminal emulator
# - Launch xterm
# - Type "If you can see this text xterm is working" in the terminal
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_leap);

sub run {
    my ($self) = @_;
    # workaround for boo#1205518
    if (is_leap("=15.4") && check_var('DESKTOP', 'gnome')) {
        select_console "root-console";
        assert_script_run('systemctl mask getty@tty2', timeout => 300);
    }
    select_console('x11', await_console => 0);
    $self->test_terminal('xterm');
}

1;
