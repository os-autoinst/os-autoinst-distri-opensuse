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

sub run {
    my ($self) = @_;
    select_console 'x11';
    $self->test_terminal('xterm');
}

1;
