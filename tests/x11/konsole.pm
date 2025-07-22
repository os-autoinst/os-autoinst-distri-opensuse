# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: konsole
# Summary: Basic functionality of konsole
# Maintainer: Fabian Vogt <fvogt@suse.de>

use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->test_terminal('konsole');
}

1;
