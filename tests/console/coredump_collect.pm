
# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: collect all coredumps
# Maintainer: Ondřej Súkup <osukup@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    $self->upload_coredumps;
}

1;
