# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openSUSEway
# Summary: Start openSUSEway WM
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base qw(opensusebasetest);
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;

    $self->wait_boot;

    select_serial_terminal;

    zypper_call('in --type pattern --recommends openSUSEway');

    select_console('user-console');

    type_string("sway -d\n");
    assert_screen('openSUSEway-workspace-1');
}

1;
