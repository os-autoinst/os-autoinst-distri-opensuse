# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: sway
# Summary: Start Sway WM
# Maintainer: rpalethorpe@suse.com

use Mojo::Base qw(opensusebasetest);
use testapi;
use serial_terminal;
use utils;

sub run {
    my ($self) = @_;

    $self->wait_boot;

    select_serial_terminal;

    zypper_call('in --type pattern --recommends sway');

    select_console('user-console');

    type_string("sway -d\n");
    assert_screen('sway-workspace-1');
}

1;
