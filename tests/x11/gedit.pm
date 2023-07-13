# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gedit
# Summary: Basic functionality of gedit
# - Launch gedit and check if it is running
# - Type "If you can see this text gedit is working." and check
# - Close gedit
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    ensure_installed('gedit');
    x11_start_program('gedit');
    $self->enter_test_text('gedit', slow => 1);
    assert_screen 'test-gedit-1';
    send_key 'alt-f4';
    assert_screen 'gedit-save-changes';
    send_key 'alt-w';
}

1;
