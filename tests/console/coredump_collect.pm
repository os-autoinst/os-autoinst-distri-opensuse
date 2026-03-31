
# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: collect all coredumps
# Maintainer: Ondřej Súkup <osukup@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Logging qw(upload_coredumps cleanup_known_coredumps);

sub run {
    my $self = shift;
    select_serial_terminal;

    cleanup_known_coredumps;
    upload_coredumps;
}

1;
